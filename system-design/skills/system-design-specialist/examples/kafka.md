# Example: Kafka

Run on 2026-10-10 with Claude Opus 5.5 in Claude Code. As the skill instructs, Claude searched the web for current releases and news before answering. The output is unedited.

## Prompt

```
What do you think of Kafka?
```

## Output

*Assuming Apache Kafka as the backbone for event streaming in a typical backend or data platform. As of October 2026 the latest release is 4.3.1.*

### What it is

Kafka is a distributed, partitioned, replicated append-only log. Producers write records to topics, and consumers read them at their own pace by tracking offsets. It sits between services as the event bus, and between operational databases and analytics as the data pipe.

### Advantages

- **The log can be replayed, and it's shared.** A record isn't deleted when someone reads it. Ten consumer groups can read the same topic independently, a new service can backfill from day one, and a bug fix can reprocess last week's events. RabbitMQ and SQS remove a message once it's acknowledged, so none of this is possible there.
- **Throughput is very high on cheap hardware.** Sequential disk I/O, batching, compression and zero-copy reads (`sendfile`) let a handful of brokers sustain hundreds of MB/s. If you're ingesting clickstream, logs or CDC at millions of events per second, few systems are as proven.
- **Ordering is guaranteed within a partition, by key.** All events for `order-123` land in one partition, in order. That's enough to build correct per-entity state machines and event-sourced aggregates without a distributed lock.
- **The ecosystem is the real moat.** Kafka Connect, Debezium CDC, Kafka Streams, Flink, Schema Registry, and managed offerings on every cloud are all available. The Kafka wire protocol has become a de facto standard: Redpanda, WarpStream, AutoMQ, Azure Event Hubs and others speak it, so you're never locked to one implementation.
- **Recent releases closed long-standing gaps.**
  - ZooKeeper is gone. Kafka 4.0 is KRaft-only, so you run one system, not two.
  - Tiered storage moves old segments to object storage, which separates retention from broker disk.
  - The KIP-848 consumer protocol makes rebalances incremental, not stop-the-world.
  - Queues for Kafka (share groups, KIP-932) became production-ready in 4.2.

### Limitations

- **Partitions are both the unit of parallelism and the unit of ordering, and they're hard to change.** Adding partitions remaps keys and breaks per-key ordering for in-flight data. In a classic consumer group, parallelism is capped at the partition count. You end up capacity-planning partitions up front, which is a strange thing to ask of an application team.
- **One poison message blocks its partition.** Classic consumers have no built-in per-message acknowledgment, retry, dead-letter queue or delayed delivery. Every team reinvents retry topics. Share groups fix acknowledgment and delivery counting, but only by giving up ordering, and there's still no native delay.
- **Exactly-once has a narrow scope.** Transactions give exactly-once for consume-transform-produce *within Kafka*. Once you write to Postgres or call an API, you're back to at-least-once and need idempotent consumers. Many teams believe EOS covers more than it does.
- **Operations remain the main cost.** Reassigning partitions physically copies data and can take hours on a large cluster. Broker disk and compute are coupled unless you use tiered storage. The configuration surface is huge: `acks`, `min.insync.replicas`, `unclean.leader.election`, `max.poll.interval.ms`, retention and segment sizing. KRaft removed one moving part, not the expertise requirement.
- **Cross-AZ networking is the hidden cost in the cloud.** With replication factor 3 across three AZs, every produced byte crosses AZ boundaries roughly twice for replication, plus consumer traffic. At AWS's $0.01/GB in each direction, that often costs more than the brokers themselves at high volume. This is why WarpStream, AutoMQ and the "diskless" designs exist. Apache accepted diskless topics (KIP-1150) as a direction in March 2026, but no Apache release includes them yet, so it's not something you can plan around today.
- **It isn't a database or an RPC bus.** You can't query by key without building a state store or a compacted topic plus a materialised view. Latency at p99 with `acks=all` is single-digit to tens of milliseconds. That's fine for events, but wrong for request/response.
- **Small deployments carry a heavy minimum.** A production setup is 3 brokers plus 3 controllers, plus monitoring and an on-call person who understands ISR. For 50 messages per second, that's overkill.

### Tradeoffs

- **A retained log versus per-message queue semantics.** You get replay, fan-out and decoupled consumers at the cost of per-message acknowledgment, routing and priorities, which RabbitMQ and SQS give you for free. Share groups narrow the gap, but Kafka is still a log that can act like a queue. It isn't a queue.
- **Throughput versus latency.** Batching (`linger.ms`, `batch.size`) and compression buy throughput by adding milliseconds. NATS or Redis Streams win on raw latency and lose on durability and ecosystem.
- **Durability versus write availability.** `acks=all` with `min.insync.replicas=2` means writes *fail* if two of three replicas are down. That's the right call for payments, but it surprises teams that expected the cluster to keep accepting writes.
- **Ordering versus parallelism.** Strict per-key order means one slow key slows its whole partition. Unordered share-group consumption scales out freely but gives up the ordering that made Kafka attractive for state.
- **Control versus cost and toil.** Self-hosting gives the best unit cost and the most toil. Confluent Cloud (now part of IBM after a deal that closed in March 2026) and MSK hand over the toil at a premium. Kafka-compatible engines like Redpanda and WarpStream trade feature parity and community size for simpler operations or object-storage economics. Apache Kafka itself remains an open Apache project, but expect vendor pricing and bundling to shift under IBM.

### Rating

| Dimension | Score | Why |
| --- | --- | --- |
| Scalability | 4/5 | Proven at trillions of messages a day. Rebalancing data and fixed partition counts make scaling slower and more manual than it should be. |
| Performance / latency | 4/5 | Throughput is best-in-class. Latency is good, not low; tuned for batches, not for p99 under a millisecond. |
| Reliability / fault tolerance | 4/5 | ISR replication and well-understood failure modes. Safe defaults since 3.0, but misconfiguration (unclean election, `min.insync.replicas=1`) still causes data loss. |
| Operational complexity | 2/5 | KRaft and tiered storage help, but reassignments, rebalances, disk planning and tuning still need specialists. |
| Cost efficiency | 2/5 | Cross-AZ replication traffic and overprovisioned disks dominate cloud bills. Diskless designs that would fix this aren't upstream yet. |
| Ecosystem & maturity | 5/5 | The largest streaming ecosystem by far, a large hiring pool, and a wire protocol other systems implement. |
| Developer experience | 3/5 | Easy to start with single-node KRaft in Docker. Consumer semantics, offset management and client configuration are full of subtle traps. |

**Overall: 8/10.** Kafka is the default backbone for durable event streaming at scale and deserves to be. It is also routinely over-adopted as a job queue by teams that would be better served by something much simpler.

### Best fit / avoid when

**Choose Kafka when** you have high-volume event streams with several independent consumers, need CDC from databases into a lake or warehouse, want event sourcing or audit logs that must be replayable, or need stream processing (Flink, Kafka Streams) over ordered per-key data. It also fits when you're already at a scale where a platform team exists to run it, or you're willing to pay for a managed service.

**Avoid it when** you need a work queue with retries, delays and per-message dead-letter queues; use SQS or RabbitMQ, or share groups only if you're already on Kafka. Also avoid it for request/response or low-latency RPC, for volumes in the hundreds of messages per second (Postgres with `LISTEN/NOTIFY`, Redis Streams or a managed queue will do), and for small teams with no one to own a stateful distributed system.

#### Sources

- [Apache Kafka 4.2.0 release announcement](https://kafka.apache.org/blog/2026/02/17/apache-kafka-4.2.0-release-announcement/)
- [Apache Kafka 4.1: the 3 big things developers need to know (The New Stack)](https://thenewstack.io/apache-kafka-4-1-the-3-big-things-developers-need-to-know/)
- [Queues for Kafka (KIP-932) preview release notes](https://cwiki.apache.org/confluence/spaces/KAFKA/pages/364349960/Queues+for+Kafka+KIP-932+-+Preview+Release+Notes)
- [Apache Kafka 4.x: what KRaft and ZooKeeper removal mean](https://andrewbaker.ninja/2026/02/17/apache-kafka-4-x-what-kraft-and-zookeeper-removal-mean/)
- [KIP-1150 accepted and the road ahead (Aiven)](https://aiven.io/blog/kip-1150-accepted-and-the-road-ahead)
- [Kafka Diskless Topics (KIP-1150): status as of July 2026](https://www.youngju.dev/split/2026-07-16-kafka-diskless-topics-kip-1150)
- [IBM to acquire Confluent for $11 billion (SD Times)](https://sdtimes.com/data/ibm-to-acquire-confluent-for-11-billion/)
- [IBM's smartest AI infrastructure move since Red Hat (Info-Tech)](https://www.infotech.com/software-reviews/vendor-technology-notes/ibm-s-smartest-ai-infrastructure-move-since-red-hat)
