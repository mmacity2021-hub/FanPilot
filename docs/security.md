# Sécurité

| Composant | Risque | Mitigation |
|---|---|---|
| WebView | XSS | CSP |
| IPC Tauri | commandes non autorisées | capabilities |
| Capteurs | accès SMC | permissions minimales |
| Updater | binaire malveillant | signature minisign |

Signaler : [SECURITY.md](../SECURITY.md).
