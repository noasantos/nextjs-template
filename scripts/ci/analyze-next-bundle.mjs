import { readFileSync, statSync } from "node:fs"
import { join, resolve } from "node:path"

function readJson(path) {
  return JSON.parse(readFileSync(path, "utf8"))
}

function flattenManifestChunks(value, out = new Set()) {
  if (Array.isArray(value)) {
    for (const entry of value) {
      flattenManifestChunks(entry, out)
    }
    return out
  }

  if (value && typeof value === "object") {
    for (const nested of Object.values(value)) {
      flattenManifestChunks(nested, out)
    }
    return out
  }

  if (typeof value === "string" && value.endsWith(".js")) {
    out.add(value)
  }

  return out
}

function formatKiB(bytes) {
  return `${(bytes / 1024).toFixed(1)} KiB`
}

const target = process.argv[2]

if (!target) {
  console.error("usage: node scripts/ci/analyze-next-bundle.mjs <path-to-.next>")
  process.exit(1)
}

const nextDir = resolve(process.cwd(), target)
const buildManifest = readJson(join(nextDir, "build-manifest.json"))
const appBuildManifest = readJson(join(nextDir, "app-build-manifest.json"))

const files = flattenManifestChunks(buildManifest)
const appFiles = flattenManifestChunks(appBuildManifest)

const allFiles = [...new Set([...files, ...appFiles])].map((file) => {
  const absolutePath = join(nextDir, file)
  const size = statSync(absolutePath).size

  return {
    file,
    size,
  }
})

allFiles.sort((left, right) => right.size - left.size)

const totalBytes = allFiles.reduce((sum, entry) => sum + entry.size, 0)
const topEntries = allFiles.slice(0, 10)

console.log("Next client bundle summary")
console.log(`Total emitted JavaScript: ${formatKiB(totalBytes)}`)

for (const entry of topEntries) {
  console.log(`${formatKiB(entry.size)}\t${entry.file}`)
}
