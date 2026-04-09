import { createDb } from "./client.js";
import { agents, companies, goals } from "./schema/index.js";

const url = process.env.DATABASE_URL;
if (!url) throw new Error("DATABASE_URL is required");

const db = createDb(url);

console.log("Seeding executive team demo data...");

const [company] = await db
  .insert(companies)
  .values({
    name: "Paperclip Demo Co",
    description: "A blank company shell with an executive team template",
    status: "active",
    budgetMonthlyCents: 50000,
  })
  .returning();

await db.insert(goals).values({
  companyId: company!.id,
  title: "Define the company plan",
  description:
    "Set the company direction, then let the CEO launch the executive team and delegate operating scope.",
  level: "company",
  status: "active",
});

const [ceo] = await db
  .insert(agents)
  .values({
    companyId: company!.id,
    name: "CEO",
    role: "ceo",
    title: "Chief Executive Officer",
    status: "idle",
    reportsTo: null,
    capabilities: "Launches the executive team and owns company-wide strategy.",
    adapterType: "process",
    adapterConfig: {},
    runtimeConfig: {},
    budgetMonthlyCents: 0,
    spentMonthlyCents: 0,
    permissions: { canCreateAgents: true },
    lastHeartbeatAt: null,
    metadata: { template: "executive_team_v1", seat: "root" },
  })
  .returning();

const executiveReports = [
  {
    name: "CFO",
    role: "cfo" as const,
    title: "Chief Financial Officer",
    capabilities: "Owns budgets, runway, and financial controls.",
  },
  {
    name: "CMO",
    role: "cmo" as const,
    title: "Chief Marketing Officer",
    capabilities: "Owns growth, positioning, and market-facing messaging.",
  },
  {
    name: "COO",
    role: "coo" as const,
    title: "Chief Operating Officer",
    capabilities: "Owns execution flow, coordination, and operational cadence.",
  },
  {
    name: "CTO",
    role: "cto" as const,
    title: "Chief Technology Officer",
    capabilities: "Owns product and engineering delivery.",
  },
] as const;

const createdExecutiveReports: Record<string, string> = {};

for (const report of executiveReports) {
  const [agent] = await db
    .insert(agents)
    .values({
      companyId: company!.id,
      name: report.name,
      role: report.role,
      title: report.title,
      status: "idle",
      reportsTo: ceo.id,
      capabilities: report.capabilities,
      adapterType: "process",
      adapterConfig: {},
      runtimeConfig: {},
      budgetMonthlyCents: 0,
      spentMonthlyCents: 0,
      permissions: { canCreateAgents: false },
      lastHeartbeatAt: null,
      metadata: { template: "executive_team_v1", seat: "direct_report" },
    })
    .returning();
  createdExecutiveReports[report.role] = agent!.id;
}

await db.insert(agents).values({
  companyId: company!.id,
  name: "CSO",
  role: "cso",
  title: "Chief Scientific Officer",
  status: "idle",
  reportsTo: createdExecutiveReports.cto,
  capabilities: "Owns research, experiments, and scientific validation.",
  adapterType: "process",
  adapterConfig: {},
  runtimeConfig: {},
  budgetMonthlyCents: 0,
  spentMonthlyCents: 0,
  permissions: { canCreateAgents: false },
  lastHeartbeatAt: null,
  metadata: { template: "executive_team_v1", seat: "cto_report" },
});

console.log("Seed complete");
process.exit(0);
