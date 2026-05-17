# Schéma GLPI officiel (As-Is)

| Fichier | Description |
|---------|-------------|
| `glpi-11.0.7-empty.sql` | Dump MySQL/MariaDB vide (structure GLPI 11.0.7) |

**Usage :** reverse engineering, requêtes baseline, EXPLAIN As-Is.

```bash
./scripts/run_explain_as_is.sh
```

Source : [glpi-project/glpi](https://github.com/glpi-project/glpi) — `install/mysql/glpi-empty.sql`.
