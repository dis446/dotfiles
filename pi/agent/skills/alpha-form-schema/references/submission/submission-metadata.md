# Submission Metadata Reference

`metadata` is a bag of contextual values captured at submit time that don't belong in `data` (because they're about the submission environment, not the form's fields). The platform writes a number of well-known keys; the object is extensible, so integrations and custom actions can attach additional keys without changes to the form definition.

## SubmissionMetadata object

| Property | Type | Description |
| --- | --- | --- |
| `timezone` | `string` | IANA timezone identifier captured from the submitter's browser at submit time (e.g., `"America/Chicago"`). |
| `offset` | `number` | UTC offset in minutes corresponding to `timezone` at submit time. |
| `origin` | `string` | The `window.location.origin` of the page that submitted the form (`https://app.example.com`). |
| `referrer` | `string` | The HTTP `Referer` header value at submit time, identifying the page that linked to the form. |
| `browserName` | `string` | User-agent-parsed browser name (e.g., `"Chrome"`, `"Safari"`). |
| `userAgent` | `string` | Raw `User-Agent` request header string. |
| `pathName` | `string` | The `window.location.pathname` of the page that submitted the form. |
| `onLine` | `boolean` | `navigator.onLine` value at submit time — `true` if the browser believed it had network connectivity. |
| `language` | `string` | Browser-preferred language tag (e.g., `"en-US"`). |
| `headers` | `Record<string, string>` | Subset of HTTP headers the server captured from the submit request. |
| `selectData` | `unknown` | Snapshot of the full option objects (label + value + any extra fields) for any `select` components whose `dataSrc` is `"resource"` or `"url"`. Lets consumers render submissions without re-fetching the source list. |

## Extension contract

`metadata` carries an open-ended index signature: any additional string key with any value is permitted (`[key: string]: unknown`). Integrations, custom actions, and downstream systems MAY add arbitrary keys. Consumers reading `metadata` SHOULD treat unrecognized keys as opaque and pass them through unchanged.

## Worked example

```json
{
  "metadata": {
    "timezone": "America/Chicago",
    "offset": -300,
    "origin": "https://app.example.com",
    "referrer": "https://app.example.com/dashboard",
    "browserName": "Chrome",
    "userAgent": "Mozilla/5.0 (...) Chrome/124.0",
    "pathName": "/forms/contact",
    "onLine": true,
    "language": "en-US",
    "headers": { "x-request-id": "req_abc123" },
    "selectData": { "country": { "label": "United States", "value": "US" } },
    "customCampaignId": "spring-2026"
  }
}
```

The trailing `customCampaignId` key shows the extension contract in practice — it isn't part of the platform-defined set, but it round-trips through the API unchanged.

> **Correlation lives on the revision, not in `metadata`.** `x-request-id` correlation in the alpha stack is a request header; the middleware records it as `requestId` on the `submission_revisions` document (see `submission-definition.md`), not as a `metadata` key. The `headers` bag may still capture an `x-request-id` value the CE server saw.

## See also

- `submission-definition.md` for where `metadata` sits on the Submission envelope.
