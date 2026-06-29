# Flagship Day 7 — Create disposable OCI VM

Spin up an Always Free **A1** instance for full dbt materialization (~\$0 if you terminate after export).

> **A1 out of capacity?** Use **`docs/LOCAL_FULL_MATERIALIZATION.md`** — monthly chunked dbt on local Docker is the recommended free fallback (no OCI required for ~9/10 scale proof).

## Deliverables

| Path | Purpose |
|------|---------|
| `docs/DAY37_CHECKLIST.md` | This checklist — OCI console steps |
| `scripts/oci_vm_bootstrap.sh` | Run on VM after SSH: swap, Postgres 15, clone repo |

## Prerequisites

- Oracle Cloud account (Always Free tier)
- Home region with **Ampere A1** capacity (phoenix, ashburn, etc. — availability varies)
- Your Mac SSH public key (`~/.ssh/id_ed25519.pub` or `id_rsa.pub`)
- Day 5 decision: **Option C — rsync** `data/raw/` from Mac

---

## Part A — OCI Console (you do this manually)

### 1. Networking (if no VCN yet)

1. **Networking → Virtual cloud networks → Create VCN**
2. Name: `aerodelay-vcn`, CIDR `10.0.0.0/16`
3. Create **public subnet** `10.0.1.0/24` with internet gateway

### 2. Security list — ingress

Allow SSH from **your IP only** (not 0.0.0.0/0):

| Source | Protocol | Port |
|--------|----------|------|
| `<your-ip>/32` | TCP | 22 |

### 3. Block volume (~150 GB) — optional but recommended

1. **Storage → Block volumes → Create**
2. Size: **150 GB**, same availability domain as the VM
3. Do **not** attach yet — attach after instance is running

### 4. Compute instance

1. **Compute → Instances → Create instance**
2. Name: `aerodelay-materialize`
3. Image: **Ubuntu 22.04** (aarch64)
4. Shape: **VM.Standard.A1.Flex**
   - OCPUs: **2**
   - Memory: **12 GB**
5. Boot volume: **50 GB** (default is fine)
6. SSH keys: paste your **public** key
7. Assign public IP
8. Create

> If shape is unavailable: try another AD in your home region, or retry off-peak. A1 capacity is the main blocker.

### 5. Attach block volume

1. Instance → **Attached block volumes → Attach**
2. Select the 150 GB volume
3. Note device path (usually `/dev/sdb`) — check on VM with `lsblk`

### 6. SSH test (exit criterion)

```bash
ssh ubuntu@<PUBLIC_IP>
```

If this works, Day 7 console work is done.

---

## Part B — VM bootstrap (run on the VM)

### Option 1 — clone repo on Mac path, scp script

From your Mac:

```bash
cd /Users/rohitmarathe/AeroDelay_Intel_Pipeline
scp scripts/oci_vm_bootstrap.sh ubuntu@<PUBLIC_IP>:~/
ssh ubuntu@<PUBLIC_IP>
```

On VM:

```bash
# If you attached 150 GB volume (check path first):
lsblk
sudo bash ~/oci_vm_bootstrap.sh --mount-device /dev/sdb

# Or without separate data volume (boot disk only — tighter on space):
sudo bash ~/oci_vm_bootstrap.sh
```

### Option 2 — clone from GitHub on VM

```bash
git clone https://github.com/rmarathe-hub/aerodelay-intelligence-pipeline.git
cd aerodelay-intelligence-pipeline
sudo bash scripts/oci_vm_bootstrap.sh --mount-device /dev/sdb --skip-clone
# then manually finish .env + init if needed
```

### Set a real Postgres password (recommended)

Before bootstrap, on VM:

```bash
export POSTGRES_PASSWORD='your-strong-password-here'
sudo -E bash ~/oci_vm_bootstrap.sh --mount-device /dev/sdb
```

Bootstrap creates `.env` with `POSTGRES_HOST=localhost` (no Airflow on VM).

---

## What bootstrap installs

| Component | Version / size |
|-----------|----------------|
| swap | 16 GB `/swapfile` |
| PostgreSQL | 15 (pgdg apt) |
| Python | 3 + venv (ingestion) |
| Tools | git, rsync, tmux, build-essential |
| Schemas | `raw`, `meta`, `staging`, `intermediate`, `marts` |
| **Not installed** | Airflow, Docker |

Postgres tuning (12 GB RAM): `shared_buffers=2GB`, `work_mem=128MB`.

If `/data` volume mounted, Postgres data dir moves to `/data/postgresql/15/main`.

---

## Verify Day 7

- [ ] `ssh ubuntu@<PUBLIC_IP>` works
- [ ] `free -h` shows **~12 GB RAM** + **16 GB swap**
- [ ] `psql --version` → PostgreSQL **15**
- [ ] `pg_isready -h localhost -U aerodelay`
- [ ] `psql -h localhost -U aerodelay -d aerodelay -c '\dn'` lists raw, meta, staging, intermediate, marts
- [ ] Repo cloned at `~/aerodelay-intelligence-pipeline`

```bash
# On VM after bootstrap:
cd ~/aerodelay-intelligence-pipeline
bash scripts/check_full_materialization_ready.sh --stage 2025
# Expect DATA NO-GO (raw not loaded yet) — that's OK for Day 7
```

---

## Cost / cleanup reminder

- Stay within Always Free: **2 OCPU A1**, **200 GB total storage** in home region
- **Terminate instance + delete boot volume + delete block volume** after Day 12–13 export
- No Airflow on VM → simpler, cheaper, faster

---

## Next (Day 8)

1. rsync 2025 raw from Mac (~1.1 GB)
2. `ingestion.*.backfill --no-download` on VM
3. `bash scripts/check_full_materialization_ready.sh --stage 2025` → expect **OVERALL GO**

See `docs/DAY35_CHECKLIST.md` for rsync commands.
