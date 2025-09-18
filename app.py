import os
import subprocess
from langchain_aws import ChatBedrock
from langgraph.graph import StateGraph
from langchain.prompts import PromptTemplate

# ---- Bedrock LLM Setup ----
llm = ChatBedrock(
    model_id="anthropic.claude-3-haiku-20240307-v1:0",
    region_name="us-east-1"
)

# ---- Prompt Templates ----
kubectl_prompt = PromptTemplate(
    input_variables=["query"],
    template="""
You are a Kubernetes assistant.
Convert the user request into the correct 'kubectl' command ONLY.
Return only the exact kubectl command without any explanation.

User request: {query}
Command:
"""
)

explain_prompt = PromptTemplate(
    input_variables=["command_output"],
    template="""
You are a Kubernetes troubleshooter.

Analyze the following Kubernetes command output.
1. If pods are failing (Pending, CrashLoopBackOff, Error), explain the exact reason and suggest fixes.
2. If there are no pods, give a concise explanation of what the command did successfully.

Output:
{command_output}

Explanation:
"""
)

# ---- Utility to run shell commands ----
def run_cmd(cmd):
    try:
        result = subprocess.run(
            cmd.split(),
            capture_output=True,
            text=True,
            check=True
        )
        return (result.stdout + result.stderr).strip()
    except subprocess.CalledProcessError as e:
        return (e.stdout + e.stderr).strip()

# ---- LangGraph Nodes ----
def generate_command(state):
    query = state["query"]
    response = llm.invoke(kubectl_prompt.format(query=query))
    text = response.content if hasattr(response, "content") else str(response)

    # Extract kubectl command
    command = None
    for line in text.splitlines():
        if line.strip().startswith("kubectl"):
            command = line.strip()
            break

    if not command:
        raise ValueError(f"LLM did not return a valid kubectl command:\n{text}")

    state["command"] = command
    return state
def execute_command(state):
    cmd = state["command"]
    print(f"\nExecuting: {cmd}")
    output = run_cmd(cmd)
    state["raw_output"] = output

    # Determine if we need pod diagnostics
    if cmd.startswith("kubectl create") or cmd.startswith("kubectl apply"):
        state["diagnostics"] = "creation_command"
    else:
        # Only run diagnostics if pods exist and have issues
        pods_exist = any(
            line.split()[0] != "" and "NAME" not in line
            for line in output.splitlines()
        )
        has_issues = any(
            status in output for status in ["Pending", "CrashLoopBackOff", "Error"]
        )

        extra_info = ""
        if pods_exist and has_issues:
            namespace = None
            if "-n" in cmd or "--namespace" in cmd:
                parts = cmd.split()
                if "-n" in parts:
                    namespace = parts[parts.index("-n") + 1]
                elif "--namespace" in parts:
                    namespace = parts[parts.index("--namespace") + 1]

            for line in output.splitlines():
                if any(status in line for status in ["Pending", "CrashLoopBackOff", "Error"]):
                    pod_name = line.split()[0]
                    if namespace:
                        extra_info += f"\n\n--- Describe {pod_name} ---\n"
                        extra_info += run_cmd(f"kubectl describe pod {pod_name} -n {namespace}")
                        extra_info += f"\n\n--- Logs {pod_name} ---\n"
                        extra_info += run_cmd(f"kubectl logs {pod_name} -n {namespace} --tail=50 || true")

        state["diagnostics"] = extra_info if extra_info else "No pods with issues detected."
    return state


def explain_output(state):
    # If it's a creation command, just return what was created
    if state.get("diagnostics") == "creation_command":
        created_items = []
        for line in state["raw_output"].splitlines():
            if any(line.startswith(prefix) for prefix in ["namespace/", "service/", "deployment/", "pod/"]):
                created_items.append(line)
        state["output"] = "Created: " + ", ".join(created_items) if created_items else "Resource created successfully."
    else:
        combined_output = state["raw_output"] + "\n\n" + state.get("diagnostics", "")
        response = llm.invoke(explain_prompt.format(command_output=combined_output))
        explanation = response.content if hasattr(response, "content") else str(response)
        state["output"] = explanation.strip()
    return state

# ---- Build LangGraph ----
workflow = StateGraph(dict)
workflow.add_node("generate_command", generate_command)
workflow.add_node("execute_command", execute_command)
workflow.add_node("explain_output", explain_output)

workflow.add_edge("generate_command", "execute_command")
workflow.add_edge("execute_command", "explain_output")

workflow.set_entry_point("generate_command")
workflow.set_finish_point("explain_output")

app = workflow.compile()

# ---- Interactive Loop ----
if __name__ == "__main__":
    print("🚀 Kubernetes Assistant (type 'exit' to quit)")
    while True:
        user_query = input("\nEnter your Kubernetes request: ")
        if user_query.lower() in ["exit", "quit"]:
            print("👋 Goodbye!")
            break
        try:
            result = app.invoke({"query": user_query})
            print("\n--- Explanation ---\n", result["output"])
        except Exception as e:
            print(f"⚠️ Error: {e}")
