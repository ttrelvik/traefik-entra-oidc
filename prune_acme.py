#!/usr/bin/env python3
import os
import json
import socket
import shutil
from datetime import datetime

ACME_FILE = 'acme.json'

def get_backup_filename():
    now = datetime.now()
    return f"acme.json.{now.strftime('%Y%m%d_%H%M%S')}.bak"

def test_dns(domain):
    try:
        # Standard DNS lookup
        socket.gethostbyname(domain)
        return True
    except socket.gaierror:
        return False

def main():
    if not os.path.exists(ACME_FILE):
        print(f"Error: {ACME_FILE} not found in the current directory.")
        return

    # 1. Create a timestamped safety backup
    backup_file = get_backup_filename()
    print(f"Creating safety backup: {backup_file} ...")
    shutil.copy2(ACME_FILE, backup_file)
    os.chmod(backup_file, 0o600)
    print("Backup created successfully.")

    # 2. Read and parse acme.json
    with open(ACME_FILE, 'r') as f:
        try:
            data = json.load(f)
        except json.JSONDecodeError as e:
            print(f"Error parsing {ACME_FILE}: {e}")
            return

    # Track domain resolution status and user removal decisions
    removal_decisions = {}
    modified = False

    # Iterate over resolvers
    for resolver_name, resolver_data in list(data.items()):
        if not isinstance(resolver_data, dict) or 'Certificates' not in resolver_data:
            continue
        
        certificates = resolver_data['Certificates']
        if not isinstance(certificates, list):
            continue

        keep_certs = []
        for cert in certificates:
            # Extract domains from this certificate block
            cert_domains = []
            domain_info = cert.get('domain', {})
            if isinstance(domain_info, dict):
                main_dom = domain_info.get('main')
                if main_dom:
                    cert_domains.append(main_dom)
                sans_doms = domain_info.get('sans')
                if isinstance(sans_doms, list):
                    cert_domains.extend(sans_doms)
            
            # Filter unique cert_domains
            cert_domains = list(set(cert_domains))

            # Test each domain
            should_drop = False
            for dom in cert_domains:
                if dom not in removal_decisions:
                    print(f"Testing DNS for {dom}... ", end="", flush=True)
                    resolves = test_dns(dom)
                    if resolves:
                        print("Resolved.")
                        removal_decisions[dom] = False
                    else:
                        print("FAILED TO RESOLVE.")
                        ans = input(f"Remove {dom} from acme.json? (y/N): ").strip().lower()
                        if ans == 'y':
                            removal_decisions[dom] = True
                        else:
                            removal_decisions[dom] = False
                
                if removal_decisions[dom]:
                    should_drop = True

            if should_drop:
                print(f"Dropping certificate block for domains: {cert_domains}")
                modified = True
            else:
                keep_certs.append(cert)
        
        resolver_data['Certificates'] = keep_certs

    # 3. Write back and set permissions
    if modified:
        print(f"Writing updated configurations back to {ACME_FILE}...")
        with open(ACME_FILE, 'w') as f:
            json.dump(data, f, indent=2)
        print("Update complete.")
    else:
        print("No changes made to acme.json.")

    # Secure permissions
    os.chmod(ACME_FILE, 0o600)
    print(f"Permissions for {ACME_FILE} secured to 600.")

if __name__ == '__main__':
    main()
