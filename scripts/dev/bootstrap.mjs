import { spawnSync } from "node:child_process";
import { platform } from "node:os";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const target = process.env.npm_config_target ?? process.argv.find((a) => a.startsWith("--target="))?.slice(9) ?? "";

function run(command, args) {
  const shown = [command, ...args].join(" ");
  console.log(`\n> ${shown}`);
  const result = spawnSync(command, args, { cwd: root, stdio: "inherit", shell: false });
  if (result.status !== 0) process.exit(result.status ?? 1);
}

if (platform() === "win32") {
  const ps = ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File"];
  const maybeTarget = target ? [target] : [];
  run("powershell.exe", [...ps, "scripts/dev/fetch-opencode.ps1", ...maybeTarget]);
  run("powershell.exe", [...ps, "scripts/dev/fetch-uv.ps1", ...maybeTarget]);
  run("powershell.exe", [...ps, "scripts/dev/fetch-skills.ps1"]);
} else {
  const maybeTarget = target ? [target] : [];
  run("bash", ["scripts/dev/fetch-opencode.sh", ...maybeTarget]);
  run("bash", ["scripts/dev/fetch-uv.sh", ...maybeTarget]);
  run("bash", ["scripts/dev/fetch-skills.sh"]);
}