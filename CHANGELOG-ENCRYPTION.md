# Encryption Feature - Changes Summary

## 📁 New Files Created

1. **scripts/encrypt-env.sh**
   - Encrypts `~/homelab/.env` → `~/homelab/.env.age`
   - Prompts for passphrase
   - Validates file exists before encrypting

2. **scripts/decrypt-env.sh**
   - Decrypts `~/homelab/.env.age` → `~/homelab/.env`
   - Auto-installs `age` if missing
   - Prompts for passphrase
   - Warns if overwriting existing .env

3. **ENCRYPTION.md**
   - Complete documentation on encryption workflow
   - Disaster recovery guide
   - Security best practices
   - FAQ section

## 🔧 Modified Files

### 1. `scripts/01-system-prep.sh`
**Change:** Added `age` to package list

```diff
    packages=(
        "curl"
        "wget"
        ...
+       "age"
    )
```

### 2. `setup.sh`
**Change:** Added automatic decryption prompt after deployment

```diff
    done
    
+   # Check if encrypted .env exists and offer to decrypt
+   if [ -f "$HOME/homelab/.env.age" ] && [ ! -f "$HOME/homelab/.env" ]; then
+       echo ""
+       log_info "Encrypted environment file detected"
+       ...
+       read -p "Would you like to decrypt it now? (Y/n): " decrypt_response
+       ...
+   fi
```

### 3. `.gitignore`
**Change:** Allow `.env.age` but block `.env`

```diff
- .env
+ *.env
+ !*.env.age
```

### 4. `README.md`
**Change:** Added encryption section in Configuration

```diff
## Configuration

### Environment Variables
...

+ ### Encrypted Environment Variables (Optional but Recommended)
+ 
+ You can encrypt your `.env` file...
+ **See [ENCRYPTION.md](./ENCRYPTION.md) for detailed instructions.**
```

## 🔄 Workflow Changes

### Before (Manual .env management)
```
1. Clone repo
2. ./setup.sh
3. Manually edit ~/homelab/.env
4. podman-compose up -d
```

### After (With encryption)
```
1. Clone repo (includes .env.age)
2. ./setup.sh
3. Setup detects .env.age and prompts to decrypt
4. Enter passphrase
5. podman-compose up -d (uses decrypted .env)
```

## 📋 Usage Examples

### Initial Setup (Creating encrypted env)
```bash
# 1. Deploy services (creates default .env)
./setup.sh

# 2. Edit with real passwords
nano ~/homelab/.env

# 3. Encrypt
./scripts/encrypt-env.sh

# 4. Commit encrypted version
git add homelab/.env.age
git commit -m "Add encrypted credentials"
git push
```

### Fresh Install (Using encrypted env)
```bash
# 1. Clone repo
git clone https://github.com/user/homelab-setup.git
cd homelab-setup

# 2. Run setup (auto-detects .env.age)
./setup.sh
# [Prompts to decrypt] → Enter passphrase

# 3. Services start with correct credentials
cd ~/homelab && podman ps
```

### Updating Credentials
```bash
# 1. Edit .env
nano ~/homelab/.env

# 2. Re-encrypt
./scripts/encrypt-env.sh

# 3. Commit
git add homelab/.env.age
git commit -m "Update passwords"
git push
```

## 🔒 Security Implications

**What's protected:**
- ✅ Database passwords
- ✅ Admin credentials  
- ✅ API keys
- ✅ Any sensitive configuration

**What's NOT protected:**
- Service names (visible in compose.yml)
- Port numbers (visible in compose.yml)
- Repository structure

**Threat model:**
- ✅ Protects against: Repository leaks, accidental commits
- ✅ Requires: Strong passphrase to decrypt
- ❌ Does NOT protect: If passphrase is compromised

## 🎯 Benefits

1. **Disaster Recovery**: Clone repo + passphrase = full restore
2. **Version Control**: Track credential changes over time (encrypted)
3. **Portability**: Easy migration to new hardware
4. **Backup**: Encrypted credentials safely stored in git
5. **No Manual Setup**: Fresh install doesn't require manual credential entry

## ⚠️ Important Notes

1. **Passphrase Management**
   - Store passphrase in password manager
   - Keep physical backup for disaster recovery
   - No recovery if passphrase is lost

2. **.gitignore Critical**
   - NEVER commit unencrypted `.env`
   - Always verify with `git status` before pushing
   - `.env.age` is safe to commit

3. **File Locations**
   - `.env.age` lives in `~/homelab/` (same as `.env`)
   - Scripts check both locations
   - Auto-created by encryption script

## 📊 File Size Impact

- `age` package: ~1MB
- `.env` file: ~1KB
- `.env.age` file: ~1KB (minimal size increase)
- Scripts: ~6KB total

## 🧪 Testing

Test the workflow:

```bash
# Test encryption
cd ~/homelab-setup
./scripts/encrypt-env.sh

# Backup original
cp ~/homelab/.env ~/homelab/.env.backup

# Remove decrypted
rm ~/homelab/.env

# Test decryption
./scripts/decrypt-env.sh

# Verify contents match
diff ~/homelab/.env ~/homelab/.env.backup
```

## 🔗 References

- [age encryption tool](https://age-encryption.org/)
- [ENCRYPTION.md](./ENCRYPTION.md) - Full documentation
- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) - If issues arise
