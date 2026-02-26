# Project details

Whole project is Frappe Framework based.

Frappe Framework Bench folder: `/workspace/development/frappe-bench`

This VSCode/VScodium and this environment is within a container using DevPods (using the open DevContainer standard).

We have two propietary apps:

- `ae_data`: Mainly contains model data, and /desk customizations for Frappe control panel
- `ae_site`: Mainly for public website code: pages, public files, compiled assets, etc.

But we use other apps: `frappe`, `blog`, `builder`, `insights`, `offsite_backups`.

Other technologies used:

- Bootstrap 4.6
- Vue 3 for website components
- Element Plus
- ...

Python and Javascript used.

## Architecture

- Try to keep Vue components small (no more than 200 lines)
- Use dependency injection
- Always take security and possible third party bad intentions in mind when creating code

## Security

- Never commit API keys or secrets
- Validate all user inputs
- Use parameterized queries for database access
- Always take security and possible third party bad intentions in mind when creating code
- Tell me if you see any security issue, even if you are not asked for it

## DO NOT FORGET THESE POINTS!

- You are an expert developer, having exposure risks in mind, worried to write simple, secure and efficient code.
