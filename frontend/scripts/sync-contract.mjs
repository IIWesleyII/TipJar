import { readFile, writeFile, mkdir } from 'node:fs/promises'

// Only public artifacts are read. contracts/.env is never copied to the browser.
const root = new URL('../', import.meta.url)
const artifact = JSON.parse(
  await readFile(
    new URL('../contracts/out/TipJar.sol/TipJar.json', root),
    'utf8',
  ),
)
const deployment = JSON.parse(
  await readFile(
    new URL('../contracts/deployments/base-sepolia.json', root),
    'utf8',
  ),
)
await mkdir(new URL('src/abi/', root), { recursive: true })
await writeFile(
  new URL('src/abi/tipJar.ts', root),
  '// Generated from Foundry. Run npm run sync:contract after contract changes.\n' +
    `export const tipJarAbi = ${JSON.stringify(artifact.abi, null, 2)} as const\n`,
)
await writeFile(
  new URL('src/deployment.json', root),
  JSON.stringify(
    {
      chainId: deployment.chainId,
      address: deployment.address,
      usdc: deployment.usdc,
      deploymentTransaction: deployment.deploymentTransaction,
    },
    null,
    2,
  ) + '\n',
)
console.log('Synced public ABI and deployment addresses.')
