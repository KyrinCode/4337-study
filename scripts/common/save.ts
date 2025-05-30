import path from "path";
import fs from "fs";
import { DeployedInfo, Environment } from "../../interfaces";

function load(env: Environment, name: string) {
  const targetPath = path.join(__dirname, "../../docs/deployed", env, name + ".json");
  try {
    const deployedInfo = JSON.parse(fs.readFileSync(targetPath, "utf8"));
    return deployedInfo as DeployedInfo;
  } catch (error: unknown) {
    return null;
  }
}

async function save(env: Environment, name: string, info: DeployedInfo) {
  const targetPath = path.join(__dirname, "../../docs/deployed", env, name + ".json");
  ensureDirectory(targetPath);
  fs.writeFileSync(targetPath, JSON.stringify(info, null, 2));
}

function ensureDirectory(filePath: string): boolean {
  const dirname = path.dirname(filePath);
  if (fs.existsSync(dirname)) {
    return true;
  }
  ensureDirectory(dirname);
  fs.mkdirSync(dirname);
  return false;
}

export { save, load };
