Helm charts for Danforge.

## Developing

### Prerequisites

- [helm](https://helm.sh/docs/intro/install/)
- [pre-commit](https://github.com/pre-commit/pre-commit)
- Python 3 (for the environment schema hooks)
- [Kyverno CLI](https://kyverno.io/docs/kyverno-cli/) v1.20.0 or later

### Setup Hooks

pre-commit install
pre-commit install-hooks

### Environment values schemas

The `helm-schema` hook generates each chart's strict `values.schema.json`.
The following hook derives `values.env.schema.json` for editor validation of
partial files in `envs/`. It relaxes required fields in merged maps, but keeps
array item requirements and forbidden-field constraints. Conditional map
constraints are omitted because their conditions may depend on inherited values.
External or internal schema references and dependencies in merged maps are not
supported by the generator.

The override schema is an editor aid, not a substitute for validating the final
merged values with Helm. Custom schema directives in environment files are
preserved.
