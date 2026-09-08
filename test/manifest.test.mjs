import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { validateManifest } from '../scripts/package-plugin.mjs';

const valid = {
  schema: 1,
  id: 'org.example.plugin',
  name: 'Example',
  version: '1.2.3',
  api_version: 1,
  entry: 'init.lua',
  description: 'Example plugin.',
  homepage: 'https://example.org/plugin',
  license: 'MIT',
  permissions: [],
};

const fixture = () => {
  const root = mkdtempSync(join(tmpdir(), 'qrate-plugin-'));
  writeFileSync(join(root, 'init.lua'), 'return {}');
  return root;
};

test('accepts a valid package manifest', () => {
  assert.equal(validateManifest({ ...valid }, fixture()).id, valid.id);
});

test('accepts an API version 2 package manifest', () => {
  assert.equal(validateManifest({ ...valid, api_version: 2 }, fixture()).api_version, 2);
});

test('rejects IDs without well-formed dotted segments', () => {
  const root = fixture();
  for (const id of ['plugin', 'org.-plugin', 'org.plugin-', 'org..plugin']) {
    assert.throws(() => validateManifest({ ...valid, id }, root), /stable lowercase dotted/);
  }
});

test('rejects traversal entry paths', () => {
  assert.throws(
    () => validateManifest({ ...valid, entry: '../init.lua' }, fixture()),
    /package root/,
  );
});

test('rejects unknown permissions', () => {
  assert.throws(
    () => validateManifest({ ...valid, permissions: ['process'] }, fixture()),
    /unsupported permission/,
  );
});

test('rejects a package for a newer host API', () => {
  assert.throws(
    () => validateManifest({ ...valid, api_version: 3 }, fixture()),
    /api_version must be 1 or 2/,
  );
});

test('accepts the registry license allowlist and rejects other licenses', () => {
  const root = fixture();
  for (const license of ['MIT', 'Apache-2.0', 'GPL-3.0-or-later', 'Unlicense']) {
    assert.equal(validateManifest({ ...valid, license }, root).license, license);
  }
  assert.throws(() => validateManifest({ ...valid, license: 'Proprietary' }, root), /license must/);
});
