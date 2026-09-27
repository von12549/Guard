const stageOrder = ["bootstrap", "analysis", "pre", "post"];
const stageLabels = { bootstrap: "Bootstrap", analysis: "Analysis", pre: "Pre", post: "Post" };

const connection = document.querySelector("#connection");
const targetList = document.querySelector("#targets");
const activeTarget = document.querySelector("#active-target");
const form = document.querySelector("#stage-form");
const profileSelect = document.querySelector("#profile");
const stageTrack = document.querySelector("#stage-track");
const dependencies = document.querySelector("#dependencies");
const executionChain = document.querySelector("#execution-chain");
const readiness = document.querySelector("#readiness");
const runButton = document.querySelector("#run-button");
const resultJson = document.querySelector("#result-json");
const resultCaption = document.querySelector("#result-caption");
const verdict = document.querySelector("#verdict");
const runsTab = document.querySelector("#runs-tab");
const plansTab = document.querySelector("#plans-tab");
const indexCaption = document.querySelector("#index-caption");
const inspectionList = document.querySelector("#inspection-list");
const documentKicker = document.querySelector("#document-kicker");
const documentTitle = document.querySelector("#document-title");
const documentStatus = document.querySelector("#document-status");
const documentBody = document.querySelector("#document-body");
const proofCaption = document.querySelector("#proof-caption");
const proofBody = document.querySelector("#proof-body");
const inspectionJson = document.querySelector("#inspection-json");

let workspace = null;
let selectedStage = "analysis";
let busy = false;
let inspectionMode = "runs";
let runCatalog = null;
let planCatalog = null;
let selectedRunId = null;
let selectedPlanId = null;
let inspectionVersion = 0;

function element(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  return node;
}

function setConnection(kind, text) {
  connection.className = `connection ${kind}`;
  connection.lastElementChild.textContent = text;
}

function showResult(payload, caption) {
  resultJson.textContent = JSON.stringify(payload, null, 2);
  resultCaption.textContent = caption;
}

function shortPath(path) {
  const pieces = path.replaceAll("\\", "/").split("/").filter(Boolean);
  return pieces.at(-1) || path;
}

function currentProfile() {
  return workspace?.profiles.find((profile) => profile.id === profileSelect.value) || null;
}

function currentTarget() {
  return workspace?.targets.find((target) => target.active) || null;
}

function renderTargets() {
  targetList.replaceChildren();
  for (const target of workspace.targets) {
    const button = element("button", `target-choice${target.active ? " active" : ""}`);
    button.type = "button";
    button.disabled = target.active || busy;
    button.dataset.projectId = target.projectId;
    button.setAttribute("aria-pressed", target.active ? "true" : "false");
    const heading = element("span", "target-name", shortPath(target.targetRoot));
    const state = element("span", "target-state", target.active ? "Active" : target.bound ? `Bound · ${target.profileId}` : "Available");
    const path = element("code", "", target.targetRoot);
    button.append(heading, state, path);
    button.addEventListener("click", () => selectTarget(target.projectId));
    targetList.append(button);
  }
  activeTarget.textContent = currentTarget()?.targetRoot || "No active Target";
}

function renderProfiles() {
  const previous = profileSelect.value;
  profileSelect.replaceChildren();
  for (const profile of workspace.profiles) {
    const option = element("option", "", `${profile.id} · ${profile.selectedModules.length} modules`);
    option.value = profile.id;
    profileSelect.append(option);
  }
  const active = currentTarget();
  const runnable = workspace.profiles.find((profile) => profile.stages.some((stage) => stage.enabled));
  const preferred = workspace.profiles.some((profile) => profile.id === active?.profileId)
    ? active.profileId
    : workspace.profiles.some((profile) => profile.id === previous) && previous
      ? previous
      : runnable?.id || workspace.profiles[0]?.id;
  profileSelect.value = preferred || "";
  profileSelect.disabled = busy || workspace.profiles.length === 0;
  renderStages();
}

function renderStages() {
  const profile = currentProfile();
  stageTrack.replaceChildren();
  for (const stageName of stageOrder) {
    const stage = profile?.stages.find((item) => item.stage === stageName);
    const item = document.createElement("li");
    const button = element("button", `stage-choice${selectedStage === stageName ? " selected" : ""}`);
    button.type = "button";
    button.disabled = busy || !stage?.enabled;
    button.setAttribute("aria-pressed", selectedStage === stageName ? "true" : "false");
    button.append(
      element("span", "stage-name", stageLabels[stageName]),
      element("span", "stage-modules", stage?.enabled
        ? `${stage.modules.length} ${stage.modules.length === 1 ? "module" : "modules"}`
        : "Not enabled")
    );
    button.addEventListener("click", () => {
      selectedStage = stageName;
      renderStages();
    });
    item.append(button);
    stageTrack.append(item);
  }

  const selected = profile?.stages.find((stage) => stage.stage === selectedStage);
  if (!selected?.enabled) {
    selectedStage = profile?.stages.find((stage) => stage.enabled)?.stage || "analysis";
    if (profile?.stages.some((stage) => stage.enabled)) return renderStages();
  }
  const last = stageOrder.indexOf(selectedStage);
  const chain = dependencies.checked ? stageOrder.slice(0, last + 1) : [selectedStage];
  executionChain.textContent = chain.map((stage) => stageLabels[stage]).join(" → ");
  runButton.textContent = `Run ${stageLabels[selectedStage]}`;
  runButton.disabled = busy || !selected?.enabled;
}

function setBusy(value) {
  busy = value;
  profileSelect.disabled = value || !workspace;
  dependencies.disabled = value;
  renderTargets();
  renderStages();
}

async function refreshWorkspace() {
  const response = await fetch("/api/v1/workspace", { credentials: "same-origin" });
  if (!response.ok) throw new Error(`Workspace endpoint returned HTTP ${response.status}.`);
  workspace = await response.json();
  renderTargets();
  renderProfiles();
  await refreshReadiness();
}

async function refreshReadiness() {
  const profile = currentProfile();
  readiness.className = "readiness checking";
  readiness.firstElementChild.textContent = "Checking runtime";
  readiness.lastElementChild.textContent = profile
    ? `${profile.selectedModules.length} installed modules selected`
    : "No installed Profile selected";
  if (!profile) return;
  try {
    const response = await fetch(`/api/v1/readiness/${encodeURIComponent(profile.id)}`, { credentials: "same-origin" });
    const payload = await response.json();
    if (!response.ok) throw new Error(payload.message || `HTTP ${response.status}`);
    readiness.className = `readiness ${payload.report.status}`;
    readiness.firstElementChild.textContent = payload.report.status === "pass" ? "Runtime ready" : "Runtime needs attention";
    const failed = payload.report.requirements.filter((item) => item.status !== "pass");
    readiness.lastElementChild.textContent = failed.length === 0
      ? `${profile.selectedModules.length} modules · ${payload.report.requirements.length} requirements pass`
      : failed.map((item) => `${item.runtime}: ${item.status}`).join(", ");
  } catch (error) {
    readiness.className = "readiness error";
    readiness.firstElementChild.textContent = "Readiness unavailable";
    readiness.lastElementChild.textContent = error.message;
  }
}

function setDocumentHeading(kicker, title, status, statusClass = "") {
  documentKicker.textContent = kicker;
  documentTitle.textContent = title;
  documentStatus.textContent = status;
  documentStatus.className = `document-status${statusClass ? ` ${statusClass}` : ""}`;
}

function setInspectionEmpty(title, message, payload = { authority: "v4-host", status: "waiting" }) {
  setDocumentHeading(inspectionMode === "runs" ? "Run evidence" : "Plan Center", title, "Waiting");
  documentBody.replaceChildren(element("p", "empty-guidance", message));
  proofBody.replaceChildren(element("p", "placeholder", "Nothing selected."));
  inspectionJson.textContent = JSON.stringify(payload, null, 2);
}

function showInspectionError(title, error) {
  setDocumentHeading(inspectionMode === "runs" ? "Run evidence" : "Plan Center", title, "Unavailable", "error");
  documentBody.replaceChildren(element("p", "empty-guidance", error.message));
  proofBody.replaceChildren(element("p", "placeholder", "The Host projection could not be loaded."));
  inspectionJson.textContent = JSON.stringify({ status: "error", message: error.message }, null, 2);
}

function addProofGroup(title, rows) {
  const group = element("section", "proof-group");
  group.append(element("h4", "", title));
  for (const row of rows) {
    const item = element("div", "proof-row");
    item.append(element("span", "", row.label), element("code", "", row.value));
    group.append(item);
  }
  proofBody.append(group);
}

function summaryLedger(items) {
  const ledger = element("div", "summary-ledger");
  for (const item of items) {
    const cell = element("div", "summary-item");
    cell.append(element("span", "summary-label", item.label), element("span", "summary-value", item.value));
    ledger.append(cell);
  }
  return ledger;
}

function resetInspection() {
  inspectionVersion += 1;
  runCatalog = null;
  planCatalog = null;
  selectedRunId = null;
  selectedPlanId = null;
  inspectionList.replaceChildren(element("p", "placeholder", "Loading Host projection…"));
}

function updateInspectionTabs() {
  const runsSelected = inspectionMode === "runs";
  runsTab.classList.toggle("selected", runsSelected);
  plansTab.classList.toggle("selected", !runsSelected);
  runsTab.setAttribute("aria-selected", runsSelected ? "true" : "false");
  plansTab.setAttribute("aria-selected", runsSelected ? "false" : "true");
  indexCaption.textContent = runsSelected ? "Host run catalog" : "Host-classified Plan pairs";
}

async function selectInspectionMode(mode) {
  if (inspectionMode === mode && ((mode === "runs" && runCatalog) || (mode === "plans" && planCatalog))) return;
  if (inspectionMode !== mode) inspectionVersion += 1;
  inspectionMode = mode;
  updateInspectionTabs();
  inspectionList.replaceChildren(element("p", "placeholder", "Loading Host projection…"));
  if (mode === "runs") await loadRuns();
  else await loadPlans();
}

function renderRunIndex() {
  inspectionList.replaceChildren();
  for (const run of runCatalog.runs) {
    const button = element("button", `index-choice${run.runId === selectedRunId ? " selected" : ""}`);
    button.type = "button";
    button.setAttribute("aria-pressed", run.runId === selectedRunId ? "true" : "false");
    button.append(
      element("span", "index-primary", stageLabels[run.stage] || run.stage),
      element("span", "index-state", run.status),
      element("span", "index-detail", `${run.runId.slice(0, 10)} · ${run.findingCount} findings`)
    );
    button.addEventListener("click", () => selectRun(run.runId));
    inspectionList.append(button);
  }
}

async function loadRuns(preferredRunId = null) {
  const version = inspectionVersion;
  const active = currentTarget();
  if (!active?.bound) {
    runCatalog = { runs: [] };
    inspectionList.replaceChildren(element("p", "placeholder", "Run a Stage to create Host evidence for this Target."));
    setInspectionEmpty("No bound runs", "This Target has no Host-bound project state yet.");
    return;
  }
  try {
    const response = await fetch("/api/v1/runs", { credentials: "same-origin" });
    const payload = await response.json();
    if (!response.ok) throw new Error(payload.message || `HTTP ${response.status}`);
    if (version !== inspectionVersion) return;
    runCatalog = payload;
    const candidate = preferredRunId || selectedRunId;
    selectedRunId = payload.runs.some((run) => run.runId === candidate) ? candidate : payload.runs[0]?.runId || null;
    renderRunIndex();
    if (selectedRunId) await selectRun(selectedRunId);
    else setInspectionEmpty("No runs recorded", "The Host run catalog is empty for this Target.", payload);
  } catch (error) {
    if (version !== inspectionVersion) return;
    inspectionList.replaceChildren(element("p", "placeholder", "Run catalog unavailable."));
    showInspectionError("Run catalog unavailable", error);
  }
}

async function selectRun(runId) {
  const version = inspectionVersion;
  selectedRunId = runId;
  renderRunIndex();
  setDocumentHeading("Loading Host evidence", runId, "Loading");
  try {
    const response = await fetch(`/api/v1/evidence/${encodeURIComponent(runId)}`, { credentials: "same-origin" });
    const payload = await response.json();
    if (!response.ok) throw new Error(payload.message || `HTTP ${response.status}`);
    if (version !== inspectionVersion || selectedRunId !== runId) return;
    renderEvidence(payload);
  } catch (error) {
    if (version !== inspectionVersion || selectedRunId !== runId) return;
    showInspectionError("Evidence unavailable", error);
  }
}

function renderEvidence(payload) {
  const result = payload.stageResult;
  setDocumentHeading(`Run ${payload.runId}`, `${stageLabels[result.stage] || result.stage} result`, result.status, result.status);
  documentBody.replaceChildren(summaryLedger([
    { label: "Exit category", value: result.exitCategory },
    { label: "Profile", value: `${result.profile.id} ${result.profile.version}` },
    { label: "Executed", value: result.executedStages.map((stage) => stageLabels[stage] || stage).join(" → ") },
    { label: "Evidence files", value: String(payload.files.length) }
  ]));

  const findings = element("section", "evidence-section");
  findings.append(element("h4", "", `Findings (${result.findings.length})`));
  if (result.findings.length === 0) findings.append(element("p", "empty-guidance", "The Host returned no findings."));
  else {
    const list = element("ul", "finding-list");
    for (const finding of result.findings) {
      const row = element("li", "finding-row");
      row.append(
        element("code", "", finding.ruleId),
        element("span", "finding-subject", finding.subject),
        element("span", "severity", finding.severity)
      );
      list.append(row);
    }
    findings.append(list);
  }
  documentBody.append(findings);

  const coverage = element("section", "evidence-section");
  coverage.append(element("h4", "", `Coverage (${result.coverage.length})`));
  if (result.coverage.length === 0) coverage.append(element("p", "empty-guidance", "The Host returned no coverage claims."));
  else {
    const table = element("table", "coverage-table");
    const head = document.createElement("thead");
    const headRow = document.createElement("tr");
    for (const label of ["Claim", "Matched", "Minimum", "Comparison"]) headRow.append(element("th", "", label));
    head.append(headRow);
    const body = document.createElement("tbody");
    for (const item of result.coverage) {
      const met = item.matched >= item.minimum;
      const row = document.createElement("tr");
      row.append(
        element("td", "", item.claimId),
        element("td", "", String(item.matched)),
        element("td", "", String(item.minimum)),
        element("td", `coverage-state ${met ? "met" : "unmet"}`, met ? "matched" : "below minimum")
      );
      body.append(row);
    }
    table.append(head, body);
    coverage.append(table);
  }
  documentBody.append(coverage);

  const modules = element("section", "evidence-section");
  modules.append(element("h4", "", `Module results (${result.moduleResults.length})`));
  const moduleList = element("ul", "module-list");
  for (const module of result.moduleResults) {
    const row = element("li", "module-row");
    row.append(element("code", "", module.moduleId), element("span", "", module.evidencePath), element("span", "severity", module.status));
    moduleList.append(row);
  }
  modules.append(moduleList);
  documentBody.append(modules);

  proofCaption.textContent = "Host hashes and evidence inventory.";
  proofBody.replaceChildren();
  addProofGroup("Authority hashes", Object.entries(result.authorityHashes).sort(([a], [b]) => a.localeCompare(b))
    .map(([label, value]) => ({ label, value })));
  addProofGroup("Evidence files", payload.files.map((file) => ({
    label: `${file.kind} · ${file.size} bytes`, value: `${file.path}\n${file.sha256}`
  })));
  inspectionJson.textContent = JSON.stringify(payload, null, 2);
}

function renderPlanIndex() {
  inspectionList.replaceChildren();
  for (const plan of planCatalog.plans) {
    const button = element("button", `index-choice${plan.id === selectedPlanId ? " selected" : ""}`);
    button.type = "button";
    button.setAttribute("aria-pressed", plan.id === selectedPlanId ? "true" : "false");
    button.append(
      element("span", "index-primary", plan.title),
      element("span", "index-state", plan.kind === "v4-native" ? "V4 native" : "Historical"),
      element("span", "index-detail", plan.id)
    );
    button.addEventListener("click", () => selectPlan(plan.id));
    inspectionList.append(button);
  }
}

async function loadPlans() {
  const version = inspectionVersion;
  try {
    const response = await fetch("/api/v1/plans", { credentials: "same-origin" });
    const payload = await response.json();
    if (!response.ok) throw new Error(payload.message || `HTTP ${response.status}`);
    if (version !== inspectionVersion) return;
    planCatalog = payload;
    selectedPlanId = payload.plans.some((plan) => plan.id === selectedPlanId) ? selectedPlanId : payload.plans[0]?.id || null;
    renderPlanIndex();
    if (selectedPlanId) await selectPlan(selectedPlanId);
    else setInspectionEmpty("No Plans found", `The Host found no Plan pairs below ${payload.planRoot}.`, payload);
  } catch (error) {
    if (version !== inspectionVersion) return;
    inspectionList.replaceChildren(element("p", "placeholder", "Plan catalog unavailable."));
    showInspectionError("Plan catalog unavailable", error);
  }
}

async function selectPlan(planId) {
  const version = inspectionVersion;
  selectedPlanId = planId;
  renderPlanIndex();
  setDocumentHeading("Loading Plan pair", planId, "Loading");
  try {
    const response = await fetch(`/api/v1/plans/${encodeURIComponent(planId)}`, { credentials: "same-origin" });
    const payload = await response.json();
    if (!response.ok) throw new Error(payload.message || `HTTP ${response.status}`);
    if (version !== inspectionVersion || selectedPlanId !== planId) return;
    renderPlan(payload);
  } catch (error) {
    if (version !== inspectionVersion || selectedPlanId !== planId) return;
    showInspectionError("Plan detail unavailable", error);
  }
}

function renderMarkdown(source) {
  const root = element("div", "markdown-view");
  let list = null;
  let listType = null;
  let inFence = false;
  let codeLines = [];
  const closeList = () => { list = null; listType = null; };
  const appendCode = () => {
    const pre = document.createElement("pre");
    pre.append(element("code", "", codeLines.join("\n")));
    root.append(pre);
    codeLines = [];
  };

  for (const line of source.replaceAll("\r\n", "\n").split("\n")) {
    if (line.startsWith("```")) {
      closeList();
      if (inFence) appendCode();
      inFence = !inFence;
      continue;
    }
    if (inFence) {
      codeLines.push(line);
      continue;
    }
    const heading = /^(#{1,6})\s+(.+)$/.exec(line);
    if (heading) {
      closeList();
      const level = Math.min(5, heading[1].length + 2);
      root.append(element(`h${level}`, "", heading[2]));
      continue;
    }
    const unordered = /^[-*+]\s+(.+)$/.exec(line);
    const ordered = /^\d+[.)]\s+(.+)$/.exec(line);
    if (unordered || ordered) {
      const type = ordered ? "ol" : "ul";
      if (!list || listType !== type) {
        closeList();
        list = document.createElement(type);
        listType = type;
        root.append(list);
      }
      list.append(element("li", "", (unordered || ordered)[1]));
      continue;
    }
    closeList();
    if (line.trim() === "") continue;
    if (line.startsWith(">")) root.append(element("blockquote", "", line.replace(/^>\s?/, "")));
    else root.append(element("p", "", line));
  }
  if (inFence || codeLines.length > 0) appendCode();
  return root;
}

function renderPlan(payload) {
  const plan = payload.plan;
  const native = plan.kind === "v4-native";
  setDocumentHeading(plan.id, plan.title, native ? "V4 native" : "Historical", plan.kind);
  const classification = element("p", `plan-classification${native ? "" : " historical"}`,
    native
      ? "Validated by the V4 Plan contract. This is a native authority presentation."
      : "Read-only V3 compatibility view. Presentation does not grant V4-native authority.");
  documentBody.replaceChildren(classification, renderMarkdown(payload.markdown));
  proofCaption.textContent = "Host classification and byte-matched Plan pair.";
  proofBody.replaceChildren();
  addProofGroup("Classification", [
    { label: "Kind", value: plan.kind },
    { label: "Presentation", value: plan.presentationMode },
    { label: "Validation", value: plan.validation }
  ]);
  addProofGroup("Plan pair", [
    { label: "Markdown", value: `${plan.markdownPath}\n${plan.markdownSha256}` },
    { label: "JSON", value: `${plan.jsonPath}\n${plan.jsonSha256}` }
  ]);
  inspectionJson.textContent = JSON.stringify(payload.document, null, 2);
}

async function refreshInspection(preferredRunId = null) {
  updateInspectionTabs();
  if (inspectionMode === "runs") await loadRuns(preferredRunId);
  else await loadPlans();
}

async function selectTarget(projectId) {
  setBusy(true);
  try {
    const response = await fetch("/api/v1/workspace/select", {
      method: "POST",
      credentials: "same-origin",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ projectId })
    });
    const payload = await response.json();
    if (!response.ok) throw new Error(payload.message || `HTTP ${response.status}`);
    await refreshWorkspace();
    showResult(payload, "The active Target changed by Host-derived project ID.");
    resetInspection();
    await refreshInspection();
  } catch (error) {
    showResult({ status: "error", message: error.message }, "The Target selection was refused.");
  } finally {
    setBusy(false);
  }
}

async function connect() {
  try {
    const response = await fetch("/api/v1/session", { credentials: "same-origin" });
    if (!response.ok) throw new Error(`Session endpoint returned HTTP ${response.status}.`);
    await response.json();
    await refreshWorkspace();
    setConnection("ready", "Loopback workspace ready");
    await refreshInspection();
  } catch (error) {
    setConnection("error", "Companion unavailable");
    showResult({ status: "error", message: error.message }, "The local Companion workspace could not start.");
    showInspectionError("Companion unavailable", error);
  }
}

profileSelect.addEventListener("change", () => {
  renderStages();
  refreshReadiness();
});
dependencies.addEventListener("change", renderStages);
runsTab.addEventListener("click", () => selectInspectionMode("runs"));
plansTab.addEventListener("click", () => selectInspectionMode("plans"));

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  setBusy(true);
  verdict.className = "verdict running";
  verdict.textContent = "Running";
  showResult({ authority: "v4-host", status: "running", stage: selectedStage }, "Waiting for the V4 Host result.");

  const request = { stage: selectedStage, profile: profileSelect.value, withDependencies: dependencies.checked };
  try {
    const response = await fetch("/api/v1/stages/run", {
      method: "POST",
      credentials: "same-origin",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(request)
    });
    const payload = await response.json();
    showResult(payload, response.ok ? "Returned unchanged from the V4 Host." : "The Companion refused or could not transport the request.");
    const hostStatus = response.ok ? payload.hostResult?.status : "error";
    verdict.className = `verdict ${hostStatus || "error"}`;
    verdict.textContent = response.ok ? (hostStatus || "Host result") : "Refused";
    if (response.ok) {
      await refreshWorkspace();
      inspectionMode = "runs";
      resetInspection();
      await refreshInspection(payload.hostResult?.runId || null);
    }
  } catch (error) {
    verdict.className = "verdict error";
    verdict.textContent = "Unavailable";
    showResult({ status: "error", message: error.message }, "No Host result was returned.");
  } finally {
    setBusy(false);
  }
});

connect();
