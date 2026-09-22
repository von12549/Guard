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

let workspace = null;
let selectedStage = "analysis";
let busy = false;

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

function renderTargets() {
  targetList.replaceChildren();
  for (const target of workspace.targets) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = `target-choice${target.active ? " active" : ""}`;
    button.disabled = target.active || busy;
    button.dataset.projectId = target.projectId;
    button.setAttribute("aria-pressed", target.active ? "true" : "false");

    const heading = document.createElement("span");
    heading.className = "target-name";
    heading.textContent = shortPath(target.targetRoot);
    const state = document.createElement("span");
    state.className = "target-state";
    state.textContent = target.active ? "Active" : target.bound ? `Bound · ${target.profileId}` : "Available";
    const path = document.createElement("code");
    path.textContent = target.targetRoot;
    button.append(heading, state, path);
    button.addEventListener("click", () => selectTarget(target.projectId));
    targetList.append(button);
  }
  const active = workspace.targets.find((target) => target.active);
  activeTarget.textContent = active?.targetRoot || "No active Target";
}

function renderProfiles() {
  const previous = profileSelect.value;
  profileSelect.replaceChildren();
  for (const profile of workspace.profiles) {
    const option = document.createElement("option");
    option.value = profile.id;
    option.textContent = `${profile.id} · ${profile.selectedModules.length} modules`;
    profileSelect.append(option);
  }
  const active = workspace.targets.find((target) => target.active);
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
    const button = document.createElement("button");
    button.type = "button";
    button.className = `stage-choice${selectedStage === stageName ? " selected" : ""}`;
    button.disabled = busy || !stage?.enabled;
    button.setAttribute("aria-pressed", selectedStage === stageName ? "true" : "false");
    const name = document.createElement("span");
    name.className = "stage-name";
    name.textContent = stageLabels[stageName];
    const modules = document.createElement("span");
    modules.className = "stage-modules";
    modules.textContent = stage?.enabled
      ? `${stage.modules.length} ${stage.modules.length === 1 ? "module" : "modules"}`
      : "Not enabled";
    button.append(name, modules);
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
  } catch (error) {
    setConnection("error", "Companion unavailable");
    showResult({ status: "error", message: error.message }, "The local Companion workspace could not start.");
  }
}

profileSelect.addEventListener("change", () => {
  renderStages();
  refreshReadiness();
});
dependencies.addEventListener("change", renderStages);

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
    if (response.ok) await refreshWorkspace();
  } catch (error) {
    verdict.className = "verdict error";
    verdict.textContent = "Unavailable";
    showResult({ status: "error", message: error.message }, "No Host result was returned.");
  } finally {
    setBusy(false);
  }
});

connect();
