# Android Studio Run Configurations Guide

## 🚀 Quick Setup: Build Variants Method (Recommended)

### Step 1: Open Build Variants
- **View** → **Tool Windows** → **Build Variants**
- You'll see a panel with your app module

### Step 2: Sync Gradle (required after adding a new flavor)
- **File** → **Sync Project with Gradle Files**
- Open the **`andriod`** folder as the project root (not the parent `70K-Bands` repo)

### Step 3: Switch Variants
- **For 70K Bands**: `bands70kDebug` or `bands70kRelease`
- **For MDF Bands**: `mdfbandsDebug` or `mdfbandsRelease`
- **For MMF Bands**: `mmfbandsDebug` or `mmfbandsRelease`

### Step 4: Run
- Click the **Run button** (▶️) or press `Shift + F10`
- Android Studio automatically builds and runs the selected variant

---

## 🎯 Advanced: Custom Run Configurations

### Creating Named Run Configurations

1. **Run** → **Edit Configurations...**
2. **Click `+`** → **Android App**

#### 70K Bands Configuration:
```
Name: 70K Bands
Module: 70K-Bands-andriod.app
Build Variant: bands70kDebug
Launch Activity: com.Bands70k.showBands
Target Device: [Your preferred emulator/device]
```

#### MDF Bands Configuration:
```
Name: MDF Bands  
Module: 70K-Bands-andriod.app
Build Variant: mdfbandsDebug
Launch Activity: com.Bands70k.showBands
Target Device: [Your preferred emulator/device]
```

### Benefits:
- **Named configurations** in the dropdown
- **One-click switching** between apps
- **Different target devices** for each variant
- **Custom launch options** per variant

---

## 🔧 Gradle Task Configurations

### For Build + Install Only:
1. **Run** → **Edit Configurations...**
2. **Click `+`** → **Gradle**

#### 70K Bands Gradle Task:
```
Name: Build & Install 70K
Gradle project: [Select your project]
Tasks: assembleBands70kDebug installBands70kDebug
Arguments: --stacktrace
```

#### MDF Bands Gradle Task:
```
Name: Build & Install MDF
Gradle project: [Select your project]  
Tasks: assembleMdfbandsDebug installMdfbandsDebug
Arguments: --stacktrace
```

---

## 📱 External Tool Configurations

### For Complete Build + Install + Launch:
1. **File** → **Settings** → **Tools** → **External Tools**
2. **Click `+`**

#### 70K Bands External Tool:
```
Name: Launch 70K Bands
Program: /bin/bash
Arguments: -c "cd $ProjectFileDir$ && ./run_70k.sh"
Working directory: $ProjectFileDir$
```

#### MDF Bands External Tool:
```
Name: Launch MDF Bands
Program: /bin/bash  
Arguments: -c "cd $ProjectFileDir$ && ./run_mdf.sh"
Working directory: $ProjectFileDir$
```

Access via: **Tools** → **External Tools** → **Launch 70K Bands**

---

## 🎯 Recommended Workflow

### For Daily Development:
1. **Use Build Variants panel** for quick switching
2. **Keep both variants** in recent run configurations
3. **Use named run configurations** for specific testing scenarios

### For Testing/QA:
1. **Use external tools** for complete build-install-launch cycles
2. **Use Gradle tasks** for CI/CD integration
3. **Create device-specific configurations** for different test scenarios

---

## 🔍 Verification

After running either configuration, verify you're running the correct app:

### In the App:
- **Title bar** shows correct app name
- **Preferences** → Title shows "70K Bands Preferences" vs "MDF Bands Preferences"
- **About/Info screen** shows correct package name

### Via ADB:
```bash
# Check running apps
adb shell dumpsys activity activities | grep -E "(70k|mdf)"

# Check installed packages  
adb shell pm list packages | grep -E "(Bands70k|mdfbands)"
```

---

## 🎸 Ready to Rock!

With these configurations set up, you can easily:
- **Switch between festivals** with a dropdown selection
- **Test both apps** on different devices simultaneously  
- **Debug festival-specific issues** efficiently
- **Maintain separate launch preferences** for each variant

Choose the method that best fits your development workflow! 🤘
