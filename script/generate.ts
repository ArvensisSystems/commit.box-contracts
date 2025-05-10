import { contracts, networks } from "../export.config";
import fs from "node:fs/promises";
import path from "node:path";

(async function () {
  let abis = {};
  let deployments = {};

  for (let i = 0; i < contracts.length; i++) {
    try {
      const f = await fs.readFile(path.join("out", `${contracts[i]}.sol`, `${contracts[i]}.json`), {
        encoding: "utf8",
      });
      const parsed = JSON.parse(f);
      abis[contracts[i]] = parsed.abi;
    } catch (e) {
      console.error(`An issue occurred trying to process the contract ABI ${contracts[i]}:`);
      console.error(e);
      process.exit(1);
    }
  }
  try {
    await fs.writeFile("generated/abi.ts", `export const abis = ${JSON.stringify(abis)}`);
  } catch (e) {
    console.error(`An issue occurred trying to save ABIs:`);
    console.error(e);
    process.exit(1);
  }

  for (let i = 0; i < networks.length; i++) {
    try {
      const f = await fs.readFile(path.join("broadcast", "Deploy.s.sol", networks[i].toString(), "run-latest.json"), {
        encoding: "utf8",
      });
      const parsed = JSON.parse(f);

      parsed.transactions.forEach((tx: any) => {
        if (tx.transactionType.includes("CREATE")) {
          if (!deployments[networks[i]]) deployments[networks[i]] = {};

          if (deployments[networks[i]][tx.contractName]) {
            deployments[networks[i]][tx.contractName].push(tx.contractAddress);
          } else {
            deployments[networks[i]][tx.contractName] = [tx.contractAddress];
          }
        }
      });
    } catch (e) {
      console.error(`An issue occurred trying to process the deployments on network ${networks[i]}:`);
      console.error(e);
      process.exit(1);
    }
  }
  try {
    await fs.writeFile("generated/networks.ts", `export const deployments = ${JSON.stringify(deployments)}`);
  } catch (e) {
    console.error(`An issue occurred trying to save deployments:`);
    console.error(e);
    process.exit(1);
  }
})();
