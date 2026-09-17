-- Tenant → environment scope map (client identifiers). Gitignored via **/secret**.
-- Copy secret_scopes.example.lua to secret_scopes.lua and fill in real names.
local M = {}

M.SCOPE_MAP = {
  dev = "env-dev",
  sit = "env-ptf-sit",
  uat = "env-ptf-uat",
  test = "env-test",
  demo = "env-demo",
  preview = "env-preview",
  th = "env-th",
  prod = "env-prod",
}

M.SCOPE_REVERSE = {
  ["env-dev"] = "dev",
  ["env-ptf-sit"] = "sit",
  ["env-ptf-uat"] = "uat",
  ["env-test"] = "test",
  ["env-demo"] = "demo",
  ["env-preview"] = "preview",
  ["env-th"] = "th",
  ["env-prod"] = "prod",
}

return M
