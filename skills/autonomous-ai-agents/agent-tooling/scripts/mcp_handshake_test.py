"""Verify an MCP stdio server end-to-end: initialize, list_tools, call one tool.

Run via a real terminal with an interpreter that has the `mcp` package, e.g.:
  ~/.local/share/uv/tools/<pkg>/bin/python scripts/mcp_handshake_test.py
Edit the constants below for the server under test. Not yet parameterized —
read constants, edit, run.
"""
import asyncio

COMMAND = "/home/ubuntu/.local/bin/skillspector"
ARGS = ["mcp"]
TOOL_NAME = "scan_skill"          # from list_tools() output
TOOL_ARGS = {"target": "/tmp", "use_llm": False, "output_format": "json"}

async def main():
    from mcp import ClientSession, StdioServerParameters
    from mcp.client.stdio import stdio_client

    params = StdioServerParameters(command=COMMAND, args=ARGS)
    async with stdio_client(params) as (read, write):
        async with ClientSession(read, write) as s:
            await s.initialize()
            tools = await s.list_tools()
            print("connected, tools:", [(t.name, list(t.inputSchema.get("properties", {}).keys())) for t in tools.tools])
            res = await s.call_tool(TOOL_NAME, TOOL_ARGS)
            text = res.content[0].text if res.content else ""
            print(f"{TOOL_NAME} round-trip ok, first 400 chars:")
            print(text[:400])

asyncio.run(main())
