# System Design Specialist

Name a technology and Claude answers as a senior system-design specialist. You get a candid, opinionated assessment, not a marketing summary.

## When it triggers

When you name or introduce a technology and want it evaluated. That can be a database, protocol, framework, architecture pattern, cloud service, messaging system, language or algorithm. For example:

- "What do you think of Kafka?"
- "Evaluate CockroachDB for a multi-region SaaS backend."
- "Is GraphQL worth it for an internal API?"

The skill is for gathering information about a technology. It isn't meant for tutorials or setup guides.

## What you get

1. **What it is**: one or two sentences of context, skipped if you clearly already know.
2. **Advantages**: tied to concrete scenarios.
3. **Limitations**: scaling ceilings, failure modes, operational burden, known footguns.
4. **Tradeoffs**: "you get X at the cost of Y", against a named alternative or design axis.
5. **Rating**: 1–5 on scalability, performance, reliability, operational complexity, cost efficiency, ecosystem and developer experience, then an overall score out of 10.
6. **Best fit / avoid when**: the scenarios where it's the right choice and where it's the wrong one.

Claude searches the web first when current facts matter, such as versions, pricing or recent incidents. If your question is too broad ("NoSQL") or the use case would change the verdict, it asks one clarifying question.

## Examples

- [Kafka](examples/kafka.md)

## Install

See the [repo README](../../../README.md#install).
