import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { mkdirSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import { basename, dirname, join, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

export const ALLOWED_LICENSES = new Set([
  'Apache-2.0',
  'BSD-2-Clause',
  'BSD-3-Clause',
  'CC-BY-4.0',
  'GPL-3.0-only',
  'GPL-3.0-or-later',
  'LGPL-3.0-only',
  'LGPL-3.0-or-later',
  'MIT',
  'Unlicense',
  'Zlib',
]);

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const ID = /^[a-z0-9](?:[a-z0-9_-]*[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9_-]*[a-z0-9])?)+$/;
const SEMVER = /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$/;

const requiredString = (manifest, field) => {
  const value = manifest[field];
  if (typeof value !== 'string' || value.trim() === '') throw new Error(`${field} must be a string`);
  return value;
};

export function validateManifest(manifest, root = ROOT) {
  if (!manifest || typeof manifest !== 'object' || Array.isArray(manifest)) {
    throw new Error('qrate-plugin.json must contain an object');
  }
  if (manifest.schema !== 1) throw new Error('schema must be 1');

  const id = requiredString(manifest, 'id');
  if (!ID.test(id)) throw new Error('id must be a stable lowercase dotted identifier');

  requiredString(manifest, 'name');
  const version = requiredString(manifest, 'version');
  if (!SEMVER.test(version)) throw new Error('version must use SemVer');

  if (manifest.api_version !== 1) {
    throw new Error('api_version must be 1');
  }

  const entry = requiredString(manifest, 'entry');
  const absoluteEntry = resolve(root, entry);
  if (
    absoluteEntry === root ||
    !absoluteEntry.startsWith(`${root}${sep}`) ||
    basename(absoluteEntry) !== basename(entry)
  ) {
    throw new Error('entry must name one file at the package root');
  }
  if (!statSync(absoluteEntry).isFile()) throw new Error(`entry does not exist: ${entry}`);

  requiredString(manifest, 'description');
  const homepage = new URL(requiredString(manifest, 'homepage'));
  if (homepage.protocol !== 'https:') throw new Error('homepage must use HTTPS');

  const license = requiredString(manifest, 'license');
  if (!ALLOWED_LICENSES.has(license)) {
    throw new Error(`license must be one of: ${[...ALLOWED_LICENSES].join(', ')}`);
  }

  if (
    !Array.isArray(manifest.permissions) ||
    manifest.permissions.some((permission) => typeof permission !== 'string')
  ) {
    throw new Error('permissions must be a string array');
  }
  const permissions = new Set(manifest.permissions);
  if (permissions.size !== manifest.permissions.length) throw new Error('permissions must be unique');
  for (const permission of permissions) {
    if (permission !== 'net') throw new Error(`unsupported permission: ${permission}`);
  }

  return manifest;
}

const git = (...args) =>
  execFileSync('git', args, { cwd: ROOT, encoding: 'utf8' })
    .trim()
    .split(/\r?\n/)
    .filter(Boolean);

export function packageFiles(manifest) {
  const excluded = /^(?:\.github|scripts|test|dist)\//;
  const files = git('ls-files').filter(
    (file) =>
      !excluded.test(file) &&
      (file === 'qrate-plugin.json' ||
        file === manifest.entry ||
        file === 'README.md' ||
        /^LICEN[CS]E/i.test(file) ||
        file.endsWith('.lua') ||
        /^(?:assets|modules|types)\//.test(file)),
  );

  for (const required of ['qrate-plugin.json', manifest.entry, 'README.md']) {
    if (!files.includes(required)) throw new Error(`${required} must be tracked by Git`);
  }
  if (!files.some((file) => /^LICEN[CS]E/i.test(file))) {
    throw new Error('a LICENSE file must be tracked at the package root');
  }
  return files;
}

export function checkPackage(root = ROOT) {
  const manifest = validateManifest(
    JSON.parse(readFileSync(join(root, 'qrate-plugin.json'), 'utf8')),
    root,
  );
  const files = packageFiles(manifest);
  const dirty = git('status', '--porcelain', '--', ...files);
  if (dirty.length) throw new Error(`commit package changes before release:\n${dirty.join('\n')}`);
  return { manifest, files };
}

function build() {
  const { manifest, files } = checkPackage();
  if (process.argv.includes('--check')) {
    console.log(`Package is valid: ${manifest.id} ${manifest.version} (${files.length} files)`);
    return;
  }

  const dist = join(ROOT, 'dist');
  mkdirSync(dist, { recursive: true });
  const archive = join(dist, `${manifest.id}-${manifest.version}.zip`);
  execFileSync('git', ['archive', '--format=zip', `--output=${archive}`, 'HEAD', '--', ...files], {
    cwd: ROOT,
    stdio: 'inherit',
  });

  const bytes = readFileSync(archive);
  const sha256 = createHash('sha256').update(bytes).digest('hex');
  writeFileSync(`${archive}.sha256`, `${sha256}  ${basename(archive)}\n`, 'utf8');
  console.log(
    JSON.stringify(
      {
        archive: relative(ROOT, archive).replaceAll('\\', '/'),
        sha256,
        bytes: bytes.length,
      },
      null,
      2,
    ),
  );
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) build();
