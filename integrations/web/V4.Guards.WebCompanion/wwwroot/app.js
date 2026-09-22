const connection = document.querySelector("#connection");
const form = document.querySelector("#stage-form");
const runButton = document.querySelector("#run-button");
const rootsList = document.querySelector("#roots");
const resultJson = document.querySelector("#result-json");
const resultCaption = document.querySelector("#result-caption");
const verdict = document.querySelector("#verdict");

function setConnection(kind, text) {
  connection.className = `connection ${kind}`;
  connection.lastChild.textContent = text;
}

function showRoots(roots) {
  rootsList.replaceChildren();
  for (const root of roots) {
    const item = document.createElement("li");
    item.className = "root-item";

    const name = document.createElement("span");
    name.className = "root-name";
    name.textContent = root.name;
    const access = document.createElement("span");
    access.className = "root-access";
    access.textContent = root.access;
    const path = document.createElement("span");
    path.className = "root-path";
    path.textContent = root.path;
    item.append(name, access, path);
    rootsList.append(item);
  }
}

function showResult(payload, caption) {
  resultJson.textContent = JSON.stringify(payload, null, 2);
  resultCaption.textContent = caption;
}

async function connect() {
  try {
    const response = await fetch("/api/v1/session", { credentials: "same-origin" });
    if (!response.ok) throw new Error(`Session endpoint returned HTTP ${response.status}.`);
    const session = await response.json();
    showRoots(session.roots);
    setConnection("ready", "Loopback session ready");
    runButton.disabled = false;
  } catch (error) {
    setConnection("error", "Companion unavailable");
    showResult({ status: "error", message: error.message }, "The local Companion session could not start.");
  }
}

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  runButton.disabled = true;
  verdict.className = "verdict running";
  verdict.textContent = "Running";
  showResult({ authority: "v4-host", status: "running" }, "Waiting for the V4 Host result.");

  const request = {
    stage: document.querySelector("#stage").value,
    profile: document.querySelector("#profile").value,
    withDependencies: document.querySelector("#dependencies").checked
  };

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
  } catch (error) {
    verdict.className = "verdict error";
    verdict.textContent = "Unavailable";
    showResult({ status: "error", message: error.message }, "No Host result was returned.");
  } finally {
    runButton.disabled = false;
  }
});

connect();
