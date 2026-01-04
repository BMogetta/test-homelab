# Optional Encrypted Configurations

This directory contains encrypted backups of your personalized configurations.

## 📁 What's Here?

Each `.age` file is an encrypted backup of a specific configuration:

| File | Contains | Restores To |
|------|----------|-------------|
| `git-config.age` | Git user name/email | `~/.gitconfig` |
| `ssh-keys.age` | SSH private/public keys | `~/.ssh/` |
| `homarr-config.age` | Homarr dashboard layout | `~/homelab/homarr/configs/` |
| `nginx-proxy-manager.age` | NPM proxy hosts & certificates | `~/homelab/nginx-proxy-manager/data/` |
| `pihole-config.age` | Custom DNS lists & settings | `~/homelab/pihole/` |

## 🔐 Encryption

All files are encrypted with `age` using passphrases you choose.

**Important:** These are OPTIONAL backups. If they don't exist, the setup will work fine - you'll just need to configure things manually.

## 🚀 Usage

### Creating Backups (After Initial Setup)

After you've configured your homelab the way you like it:

```bash
./scripts/encrypt-config.sh
```

This will:
1. Ask which configurations to encrypt
2. Prompt for passphrase for each
3. Create `.age` files in this directory

Then commit them:
```bash
git add configs/
git commit -m "feat: add encrypted configurations"
git push
```

### Restoring Backups (Fresh Install)

When setting up on a new machine:

```bash
# Option 1: Automatic (during setup.sh)
./setup.sh
# Will detect and offer to restore configs

# Option 2: Manual (after setup.sh)
./scripts/decrypt-configs.sh
```

This will:
1. Show available encrypted configs
2. Ask which ones to restore
3. Prompt for passphrases
4. Extract to correct locations

## 📝 Best Practices

### Passphrases

**Option A: One passphrase for all**
- Easier to remember
- Use a strong, unique passphrase
- Store in password manager

**Option B: Different passphrases**
- More secure
- Different sensitivity levels
- Example: weak for homarr, strong for SSH keys

### What to Encrypt

**Recommended:**
- ✅ `git-config.age` - Save your identity
- ✅ `ssh-keys.age` - Your authentication keys
- ⚠️  `homarr-config.age` - Nice to have (if customized)

**Optional:**
- `nginx-proxy-manager.age` - Only if you have many proxy hosts configured
- `pihole-config.age` - Only if you have custom blocklists/whitelists

**Don't Need:**
- Service data (databases, media, etc.) - Use regular backups
- Default configurations - Can be recreated

## 🔄 Workflow Example

### First Time Setup
```bash
# 1. Fresh install
git clone https://github.com/BMogetta/test-homelab.git
cd test-homelab
./setup.sh

# 2. Configure everything manually
# - Set up git
# - Configure services
# - Customize Homarr dashboard
# - Add Nginx proxy hosts

# 3. Encrypt your configurations
./scripts/encrypt-config.sh

# 4. Commit encrypted configs
git add configs/
git commit -m "feat: add my encrypted configs"
git push
```

### Disaster Recovery
```bash
# 1. Clone repo
git clone https://github.com/BMogetta/test-homelab.git
cd test-homelab

# 2. Run setup (detects encrypted configs)
./setup.sh
# Prompts: "Restore optional configurations?"
# Answer: Yes
# Enter passphrases when prompted

# 3. Everything restored!
# - Git configured
# - SSH keys in place
# - Services configured
# - Ready to use
```

## ⚠️ Important Notes

1. **Passphrases are not stored anywhere**
   - If you forget, there's no recovery
   - Keep physical backup of passphrases

2. **Configs are optional**
   - Setup works without them
   - Fresh start is always an option

3. **Not for service data**
   - These are CONFIGURATION backups
   - Use `./scripts/backup.sh` for data backups

4. **Privacy**
   - Encrypted files are safe in public repos
   - BUT: Don't encrypt sensitive production data here
   - This is for homelab/personal use

## 🆘 Troubleshooting

**"Decryption failed"**
- Wrong passphrase
- Corrupted .age file
- Try again or skip and configure manually

**"Directory doesn't exist"**
- Run `./setup.sh` first
- Creates necessary directories
- Then restore configs

**"File already exists"**
- Backup will be created automatically
- Choose to overwrite or skip
- Original saved as `.backup`

## 📚 Related Documentation

- [ENCRYPTION.md](../ENCRYPTION.md) - Details on .env encryption
- [README.md](../README.md) - Main setup instructions
- [TROUBLESHOOTING.md](../TROUBLESHOOTING.md) - Common issues
