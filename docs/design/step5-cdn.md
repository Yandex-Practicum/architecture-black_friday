# Task 6: CDN

This fifth design variant builds on the Task 5 service-discovery architecture and adds regional CDN edge locations:

- Users in EU, US, and APAC send static-content requests to their nearest CDN edge: `cdn-eu`, `cdn-us`, or `cdn-apac`.
- Each CDN edge pulls static content from the `static-content-origin` object-storage origin on a cache miss and serves later requests locally.
- Users can still send dynamic API requests through APISIX to the horizontally scaled `pymongo-api` instances.
- The API instances retain the Redis cache and `mongos` connection to the sharded MongoDB cluster with two three-member replica sets.

The diagram explicitly shows regional users, regional CDN nodes, the static-content origin, and the existing dynamic application path.

Diagram: [step5-cdn.drawio](step5-cdn.drawio)
