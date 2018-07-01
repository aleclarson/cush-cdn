# cush-cdn v0.0.3

Local asset server for development. Built-in support for [cush][1].

[1]: https://github.com/aleclarson/cush

```js
// Create the server.
const cdn = require('cush-cdn')(options);
```

The server constructor takes [these options][2] and returns a [slush][3] instance.

Additional options:
- `bucketDir: ?string` the directory where buckets are cached

[2]: https://github.com/aleclarson/slush#options
[3]: https://github.com/aleclarson/slush

### Fetching an asset

Send a GET request to `/b/path/to/example.js` with an `X-Bucket` header
equal to the desired bucket's unique identifier.

### Adding a project

1. Save assets in your project's `./assets/` directory

2. Add a `.cushignore` file to the `./assets/` directory (optional)

   - pattern syntax is detailed [here](https://github.com/aleclarson/recrawl#pattern-syntax)
   - paths ignored by default are:
     - `/.cushignore`
     - `.DS_Store`
     - `*.swp`

3. Export the `bundles` object in your project's `cush.config.js`

```js
exports.bundles = {
  'main.js': 'bundle.web.js',
  'styles/main.css': {
    name: 'bundle.css',
    target: 'web',
  }
};
```

4. Register the project with `cush-cdn`

```js
cdn.addProject('/path/to/project');

// Get the default bucket of your project by its name.
cdn.getBucket('my-project');
```

In the future, you may be able to share buckets between projects.

## JavaScript API

#### `loadProject(root: string): void`

Register a project with the server.

Its default bucket is created (located at `./assets/`).
Its bundles are registered with the default bucket.

#### `dropProject(root: string): boolean`

Stop serving a project's assets.

Returns true when a project exists.

#### `getBucket(id: string): ?Bucket`

Get a `Bucket` object by its unique identifier.

#### `loadBucket(id: string, options: ?Object)`

Create a `Bucket` object.

The given `id` string must be unique.

Available options:
- `root: string`
- `only: ?string[]` whitelist for filenames
- `skip: ?string[]` blacklist for filenames

#### `dropBucket(id: string): boolean`

Destroy a `Bucket` by its unique identifier.

Returns true when a bucket exists.

### `Bucket` class

Properties:
- `id: string`
- `root: string`
- `dest: string`
- `only: string[]`
- `skip: string[]`
- `events: EventEmitter`

The `events` property is an [se.EventEmitter](https://github.com/aleclarson/socket-events/blob/master/events.js#L3-L65) object.

#### `has(name: string): boolean`

Returns true if the asset exists.

#### `get(name: string): ?string|function`

When an asset is cached on disk, its cached filename is returned.
This filename can be used to read the asset from its bucket.

#### `patch(values: Object): void`

Patch the asset manifest.

See the `PATCH /b/assets.json` section for more details.

#### `put(name: string, value: string|function): void`

Add an asset to the bucket.

When the `value` is a function, it's passed the HTTP response object
and may return a promise, readable stream, string, or falsy.

#### `delete(name: string): void`

Remove an asset from the bucket.

#### `query(options: Object): Promise<Object>`

Use [`wch.query`](https://github.com/aleclarson/wch) on the bucket root.

The query API is currently undocumented.

## REST API

All `/b/` requests must include an `X-Bucket` header.

### `GET /b/[asset]`

Fetch an asset.

The response headers include:
- `Content-Type`
- `Content-Length`
- `Cache-Control: no-store`

### `GET /b/assets.json`

Fetch the asset manifest, which maps asset names to their production identifiers.

When a value is `true`, the asset name is used as-is in production.

By setting the `accepts` header to `text/event-stream`, you will receive
change events as they happen. The [socket-events][4] protocol is used.

[4]: https://github.com/aleclarson/socket-events#event-serialization

### `PATCH /b/assets.json`

Patch the asset manifest.

The request body must be a JSON object where the keys are asset names
and each value is a string, `true` literal, or `null` literal.

When a value is `null`, the asset is deleted from the bucket.
