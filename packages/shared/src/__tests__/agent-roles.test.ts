import { describe, expect, it } from "vitest";
import { AGENT_ROLE_LABELS, AGENT_ROLES } from "../constants.js";

describe("agent role catalog", () => {
  it("includes the executive roles needed by the default company template", () => {
    expect(AGENT_ROLES).toEqual(
      expect.arrayContaining(["ceo", "cfo", "cmo", "coo", "cto", "cso"]),
    );
  });

  it("exposes stable labels for the executive roles", () => {
    expect(AGENT_ROLE_LABELS.ceo).toBe("CEO");
    expect(AGENT_ROLE_LABELS.cfo).toBe("CFO");
    expect(AGENT_ROLE_LABELS.cmo).toBe("CMO");
    expect(AGENT_ROLE_LABELS.coo).toBe("COO");
    expect(AGENT_ROLE_LABELS.cto).toBe("CTO");
    expect(AGENT_ROLE_LABELS.cso).toBe("CSO");
  });
});
