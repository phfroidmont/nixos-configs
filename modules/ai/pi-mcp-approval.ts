import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// OpenCode asks before these MCP tools run; pi has no permission rules of its own.
// Odoo has no model whitelist on 19.0 Online and runs in YOLO mode, and Stripe
// moves money: every tool but the read-only ones waits for approval.
const gated = [/^mcp__odoo__/, /^mcp__stripe__/, /^mcp__playwright__browser_run_code_unsafe$/];
const readOnly = new Set([
	"mcp__odoo__aggregate_records",
	"mcp__odoo__get_current_context",
	"mcp__odoo__get_fields",
	"mcp__odoo__get_record",
	"mcp__odoo__list_models",
	"mcp__odoo__list_resource_templates",
	"mcp__odoo__search_records",
	"mcp__stripe__list_available_accounts_or_orgs",
	"mcp__stripe__manage_stripe_accounts",
	"mcp__stripe__search_stripe_documentation",
	"mcp__stripe__stripe_analytics",
	"mcp__stripe__stripe_api_details",
	"mcp__stripe__stripe_api_read",
	"mcp__stripe__stripe_api_search",
	"mcp__stripe__stripe_implementation_planner",
]);

export default function (pi: ExtensionAPI) {
	pi.on("tool_call", async (event, ctx) => {
		const name = event.toolName;
		if (readOnly.has(name) || !gated.some((pattern) => pattern.test(name))) return;
		const approved = ctx.hasUI && (await ctx.ui.confirm(`Run ${name}?`, JSON.stringify(event.input, null, 2)));
		if (!approved) return { block: true, reason: `The user did not approve ${name}.` };
	});
}
