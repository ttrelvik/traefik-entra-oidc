# Traefik with Entra ID (Azure AD) SSO

This project provides a secure, ready-to-deploy configuration for a Traefik v3 reverse proxy using Docker Compose. 

It includes a pre-configured forward authentication service to protect your backend applications with Single Sign-On (SSO) using Microsoft Entra ID (formerly Azure AD) via the OIDC protocol. It should be easily adaptable to other OIDC providers if necessary.

This setup is designed to be a secure-by-default gateway for your self-hosted services, with automatic HTTPS certificate management via Let's Encrypt (you just have to generate the proper DNS records in advance).

---

## Features

* **Traefik v3:** A modern, powerful reverse proxy and load balancer.
* **SSO with Entra ID:** Protects services using `traefik-forward-auth` and the OIDC standard.
* **Automatic HTTPS:** Manages TLS certificates automatically using Let's Encrypt.
* **Secure by Default:** The Docker provider is configured to not expose services unless they are explicitly enabled with labels.
* **SSO-Protected Dashboard:** The Traefik dashboard is enabled and pre-configured to be protected by the SSO middleware.
* **Reusable SSO:** Other services you deploy behind Traefik can also be configured to use this SSO middleware.

---

## Prerequisites

Before you begin, you will need:
* Docker and Docker Compose installed on your server.
* A registered domain name pointed at your server's IP address.
* A Microsoft Entra ID (Azure AD) account.
* An **App Registration** created in Entra ID for this application, with a client secret generated.

### A Note on Redirect URIs

A **Redirect URI** (also known as a Reply URL) is a critical security feature of the OIDC/OAuth2 protocol. After a user successfully signs in with Microsoft, Entra ID will only send them back to a pre-approved, whitelisted URI. This prevents attackers from intercepting the authentication token by redirecting the user to a malicious site.

For this project, `traefik-forward-auth` handles the login callback from Microsoft. Based on the `AUTH_HOST` environment variable you set, the service will listen for this callback at `https://auth.${DOMAIN}/_oauth`.

You must add this exact URL to your App Registration in the Entra ID portal:

1.  Navigate to your App Registration in the Entra ID admin center.
2.  Go to the **Authentication** section.
3.  Click **Add a platform** and select **Web**.
4.  In the **Redirect URIs** field, enter:
    ```
    [https://auth.your.domain/_oauth](https://auth.your.domain/_oauth)
    ```
    (replacing `your.domain` with the value of your `${DOMAIN}` variable)
5.  Click **Configure**.

If this URI is not correctly configured, you will receive an `AADSTS50011` error from Microsoft during the login attempt.

---

## How to Use

1.  **Clone the Repository**
    Clone this repository to your server, for example, under `~/services/traefik-entra-oidc`.

2.  **Create the `.env` File**
    Create a file named `.env` in the root of this project directory. Copy the contents of the example below and fill in your own values.

3.  **Create the `acme.json` File**
    Traefik needs a file to store your Let's Encrypt certificates. Create an empty file and set its permissions to be readable and writable only by the owner.
    ```bash
    touch acme.json
    chmod 600 acme.json
    ```

4.  **Start the Stack**
    With your `.env` file configured, run Docker Compose to start the services.
    ```bash
    docker compose up -d
    ```

    Traefik will now be running and will automatically obtain SSL certificates for `traefik.${DOMAIN}` and `auth.${DOMAIN}`.

---

## Configuration (`.env` Variables)

You must create a `.env` file and set the following variables for the stack to work correctly:

| Variable              | Description                                                                                              | Example                                       |
| --------------------- | -------------------------------------------------------------------------------------------------------- | --------------------------------------------- |
| `DOMAIN`              | Your root domain name. Used for the Traefik dashboard and auth host.                              | `example.com`                                 |
| `LETSENCRYPT_EMAIL`   | The email address to register with Let's Encrypt for certificate notifications.                     | `admin@example.com`                           |
| `TENANT_ID`           | Your Microsoft Entra ID Tenant ID, found on your Entra ID overview page.                           | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`        |
| `CLIENT_ID`           | The Application (client) ID from your Entra App Registration.                                        | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`        |
| `CLIENT_SECRET`       | The client secret you generated in your Entra App Registration.                                      | `aBcDeFgHiJkL~mNoPqRsTuVwXyZ.12345`            |
| `FORWARD_AUTH_SECRET` | A long, random string used to sign authentication cookies. Generate one with `openssl rand -hex 32`. | `a1b2c3d4e5f6...`                             |
| `ALLOWED_USERS`       | A comma-separated list of email addresses that are allowed to log in.                                | `user1@example.com,user2@example.com`         |


---

## Protecting Other Services

To protect another container with the SSO you've just configured, add the following label to its service definition in its `docker-compose.yml` file:

```yaml
services:
  whoami:
    image: "traefik/whoami"
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.whoami.rule=Host(`whoami.your.domain`)"
      - "traefik.http.routers.whoami.entrypoints=https"
      - "traefik.http.routers.whoami.tls.certresolver=myresolver"
      # This line applies the SSO middleware we defined in this project
      - "traefik.http.routers.whoami.middlewares=sso-auth@docker"
```
