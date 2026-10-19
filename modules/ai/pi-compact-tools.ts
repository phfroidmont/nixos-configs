import type { ExtensionAPI, Theme, ToolRenderers } from "@earendil-works/pi-coding-agent";
import { formatReadLineRange } from "@earendil-works/pi-coding-agent";
import { Box, type Component, Container, Text, TruncatedText } from "@earendil-works/pi-tui";
import { homedir } from "node:os";

// Collapsed, a tool call is one line: its status, the tool, and what it acted on.
// A failure adds the last lines of its output. Ctrl+O, or a click on the call,
// shows pi's own rendering with the full arguments and output.

type RenderCall = NonNullable<ToolRenderers["renderCall"]>;
type RenderResult = NonNullable<ToolRenderers["renderResult"]>;
type RenderContext = Parameters<RenderCall>[2];
type ToolResult = Parameters<RenderResult>[0];
type Status = "running" | "ok" | "error" | "cancelled";
type NestedCall = { name: string; args: string; status: Status };

interface Row {
	head: Container;
	line: string;
	diffStat: string;
	originalCall?: Component;
	originalResult?: Component;
}

const ERROR_TAIL_LINES = 3;
const NESTED_CALLS_SHOWN = 8;
const ANSI = /\x1b\[[0-9;?]*[ -/]*[@-~]/g;

function row(context: RenderContext): Row {
	context.state.compactTools ??= { head: new Container(), line: "", diffStat: "" };
	return context.state.compactTools;
}

function attempt<T>(render: () => T): T | undefined {
	try {
		return render();
	} catch {
		return undefined;
	}
}

function statusIcon(status: Status, theme: Theme): string {
	switch (status) {
		case "running":
			return theme.fg("warning", "…");
		case "ok":
			return theme.fg("dim", "✓");
		case "error":
			return theme.fg("error", "✗");
		case "cancelled":
			return theme.fg("dim", "⊘");
	}
}

function shortPath(value: unknown): string {
	const path = typeof value === "string" && value ? value : ".";
	const home = homedir();
	return path.startsWith(home) ? `~${path.slice(home.length)}` : path;
}

function firstLine(value: unknown): string {
	const lines = String(value ?? "")
		.trim()
		.split("\n");
	return lines.length > 1 ? `${lines[0]} …` : lines[0];
}

function argsPreview(args: unknown): string {
	if (args === null || typeof args !== "object") return args === undefined ? "" : String(args);
	return Object.values(args)
		.map((value) => (typeof value === "string" ? firstLine(value) : JSON.stringify(value)))
		.join(" ");
}

function describe(toolName: string, args: any, theme: Theme): string {
	const title = (text: string) => theme.fg("toolTitle", theme.bold(text));
	const target = (text: string) => theme.fg("accent", text);
	const detail = (text: string) => theme.fg("muted", text);
	switch (toolName) {
		case "read": {
			const range = formatReadLineRange(args?.offset, args?.limit);
			return `${title("read")} ${target(shortPath(args?.path))}${detail(range)}`;
		}
		case "bash":
			return `${title("$")} ${firstLine(args?.command)}`;
		case "edit":
			return `${title("edit")} ${target(shortPath(args?.path ?? args?.file_path))}`;
		case "write": {
			const lines = typeof args?.content === "string" ? args.content.split("\n").length : 0;
			return `${title("write")} ${target(shortPath(args?.path))} ${detail(`${lines} lines`)}`;
		}
		case "grep": {
			const glob = args?.glob ? ` ${args.glob}` : "";
			return `${title("grep")} ${target(String(args?.pattern ?? ""))} ${detail(shortPath(args?.path) + glob)}`;
		}
		case "find":
			return `${title("find")} ${target(String(args?.pattern ?? ""))} ${detail(shortPath(args?.path))}`;
		case "ls":
			return `${title("ls")} ${target(shortPath(args?.path))}`;
		case "codemode":
			return title("codemode");
	}
	const mcp = /^mcp__(.+?)__(.+)$/.exec(toolName);
	return `${title(mcp ? `${mcp[1]} ${mcp[2]}` : toolName)} ${detail(argsPreview(args))}`;
}

// Codemode cuts long argument JSON for display, which then no longer parses:
// keep its first string argument, such as a bash command.
function nestedArgs(json: string): unknown {
	const parsed = attempt(() => JSON.parse(json));
	if (parsed !== undefined) return parsed;
	const first = /^\{"(\w+)":"((?:[^"\\]|\\.)*)/.exec(json);
	const value = first && attempt(() => JSON.parse(`"${first[2]}"`));
	return typeof value === "string" ? { [first[1]]: `${value.replace(/\.\.\.$/, "")}…` } : undefined;
}

function describeNested(call: NestedCall, theme: Theme): string {
	const args = nestedArgs(call.args);
	if (args !== undefined) return describe(call.name, args, theme);
	return `${theme.fg("toolTitle", theme.bold(call.name))} ${theme.fg("muted", call.args)}`;
}

function duration(context: RenderContext, theme: Theme): string {
	const ms = context.durationMs;
	if (ms === undefined || ms < 1000) return "";
	const seconds = ms / 1000;
	const text = seconds < 60 ? `${seconds.toFixed(1)}s` : `${Math.floor(seconds / 60)}m ${Math.round(seconds % 60)}s`;
	return ` ${theme.fg("dim", text)}`;
}

function textOutput(result: ToolResult): string {
	return result.content
		.flatMap((block) => (block.type === "text" ? [block.text] : []))
		.join("\n")
		.replace(ANSI, "")
		.replace(/\r/g, "");
}

function diffStat(result: ToolResult, theme: Theme): string {
	const diff = (result.details as { diff?: string } | undefined)?.diff;
	if (!diff) return "";
	const lines = diff.split("\n");
	const added = lines.filter((line) => line.startsWith("+")).length;
	const removed = lines.filter((line) => line.startsWith("-")).length;
	return (
		(added ? ` ${theme.fg("toolDiffAdded", `+${added}`)}` : "") +
		(removed ? ` ${theme.fg("toolDiffRemoved", `-${removed}`)}` : "")
	);
}

function drawHead(state: Row, theme: Theme, context: RenderContext): void {
	const line = state.line + state.diffStat + duration(context, theme);
	state.head.clear();
	state.head.addChild(new TruncatedText(line, context.outputPad, 0));
}

// pi's own renderers draw inside a padded panel unless they frame themselves.
function framed(component: Component, original: ToolRenderers | undefined, theme: Theme, context: RenderContext) {
	if (original?.renderShell === "self") return component;
	const bg = context.isPartial ? "toolPendingBg" : context.isError ? "toolErrorBg" : "toolSuccessBg";
	const box = new Box(context.outputPad, 0, (text) => theme.bg(bg, text));
	box.addChild(component);
	return box;
}

// MCP tools have no renderers of their own.
function fallbackCall(toolName: string, args: unknown, theme: Theme): Component {
	const entries = args !== null && typeof args === "object" ? Object.entries(args) : [];
	const lines = entries.flatMap(([key, value]) =>
		`${key}: ${typeof value === "string" ? value : JSON.stringify(value, null, 2)}`.split("\n"),
	);
	const title = theme.fg("toolTitle", theme.bold(toolName));
	return new Text([title, ...lines.map((line) => theme.fg("muted", `  ${line}`))].join("\n"), 0, 0);
}

function fallbackResult(result: ToolResult, theme: Theme): Component {
	const output = textOutput(result).trim();
	const lines = output ? ["", ...output.split("\n")] : [];
	return new Text(lines.map((line) => theme.fg("toolOutput", line)).join("\n"), 0, 0);
}

function nestedCalls(result: ToolResult, theme: Theme): string[] {
	const calls = (result.details as { calls?: NestedCall[] } | undefined)?.calls ?? [];
	const shown = calls.slice(-NESTED_CALLS_SHOWN);
	const lines = shown.map((call) => `  ${statusIcon(call.status, theme)} ${describeNested(call, theme)}`);
	if (shown.length < calls.length) lines.unshift(theme.fg("dim", `  … ${calls.length - shown.length} earlier calls`));
	return lines;
}

function errorTail(result: ToolResult, theme: Theme): string[] {
	return textOutput(result)
		.split("\n")
		.map((line) => line.trimEnd())
		.filter(Boolean)
		.slice(-ERROR_TAIL_LINES)
		.map((line) => theme.fg("toolOutput", `  ${line}`));
}

export default function (pi: ExtensionAPI) {
	pi.registerToolRenderer((toolName, next) => {
		const original = next();
		return {
			renderShell: "self",
			renderCall(args, theme, context) {
				const state = row(context);
				// Keep pi's renderers running so their state (timers, edit previews) stays current.
				const originalContext = { ...context, lastComponent: state.originalCall };
				state.originalCall = attempt(() => original?.renderCall?.(args, theme, originalContext));
				if (context.expanded) {
					return framed(state.originalCall ?? fallbackCall(toolName, args, theme), original, theme, context);
				}
				const status = context.isError ? "error" : context.isPartial ? "running" : "ok";
				state.line = `${statusIcon(status, theme)} ${describe(toolName, args, theme)}`;
				drawHead(state, theme, context);
				return state.head;
			},
			renderResult(result, options, theme, context) {
				const state = row(context);
				const originalContext = { ...context, lastComponent: state.originalResult };
				state.originalResult = attempt(() => original?.renderResult?.(result, options, theme, originalContext));
				if (options.expanded) {
					return framed(state.originalResult ?? fallbackResult(result, theme), original, theme, context);
				}
				// The call line is drawn before its result; add the result's diff size to it.
				state.diffStat = toolName === "edit" ? diffStat(result, theme) : "";
				drawHead(state, theme, context);
				const lines = [
					...(toolName === "codemode" ? nestedCalls(result, theme) : []),
					...(context.isError ? errorTail(result, theme) : []),
				];
				const body = new Container();
				for (const line of lines) body.addChild(new TruncatedText(line, context.outputPad, 0));
				return body;
			},
		};
	});
}
