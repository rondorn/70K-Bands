# 🚀 MANUAL CORE DATA REBUILD GUIDE

## ✅ **Status: Core Data Model Removed - Xcode Should Work Now!**

The problematic `DataModel.xcdatamodeld` has been completely removed. Xcode should now open without crashing.

---

## 🔧 **Step 1: Verify Xcode Works**

1. **Open Xcode project** - should work without crashing now
2. **Clean build folder**: Product → Clean Build Folder
3. **Build project**: ⌘+B (should succeed)

---

## 🏗️ **Step 2: Create New Core Data Model**

### **Create the Model File:**
1. **Right-click on project** → New File
2. **Select**: Core Data → Data Model
3. **Name it**: `DataModel`
4. **Save location**: Project root (same level as other files)

### **Verify Creation:**
- You should see `DataModel.xcdatamodeld` in your project
- Click on it - should open the visual editor without crashing
- You should see an empty canvas to add entities

---

## 🎯 **Step 3: Add Entities with COMPLETE Structure**

### **Entity 1: Band (Complete Structure)**
1. **Click + button** to add entity
2. **Name**: `Band`
3. **Add ALL attributes**:
   - `bandName` (String, required, optional=NO)
   - `country` (String, optional, optional=YES)
   - `genre` (String, optional, optional=YES)
   - `noteworthy` (String, optional, optional=YES)
   - `priorYears` (String, optional, optional=YES)
   - `officialSite` (String, optional, optional=YES)
   - `imageUrl` (String, optional, optional=YES)
   - `youtube` (String, optional, optional=YES)
   - `metalArchives` (String, optional, optional=YES)
   - `wikipedia` (String, optional, optional=YES)
   - `eventYear` (Integer 32, required, optional=NO)
   - `createdAt` (Date, required, optional=NO)
   - `updatedAt` (Date, required, optional=NO)

4. **Test**: Build project (⌘+B) - should succeed
5. **Test**: Click on DataModel - should still open

### **Entity 2: Event (Complete Structure)**
1. **Add new entity**: `Event`
2. **Add ALL attributes**:
   - `location` (String, optional, optional=YES)
   - `date` (String, optional, optional=YES)
   - `day` (String, optional, optional=YES)
   - `startTime` (String, optional, optional=YES)
   - `endTime` (String, optional, optional=YES)
   - `eventType` (String, optional, optional=YES)
   - `descriptionUrl` (String, optional, optional=YES)
   - `eventImageUrl` (String, optional, optional=YES)
   - `notes` (String, optional, optional=YES)
   - `timeIndex` (Double, required, optional=NO)
   - `eventYear` (Integer 32, required, optional=NO)
   - `createdAt` (Date, required, optional=NO)
   - `updatedAt` (Date, required, optional=NO)

3. **Test**: Build project - should succeed
4. **Test**: DataModel should still open

### **Entity 3: UserPriority (Complete Structure)**
1. **Add new entity**: `UserPriority`
2. **Add ALL attributes**:
   - `priorityLevel` (Integer 16, required, optional=NO)
   - `eventYear` (Integer 32, required, optional=NO)
   - `createdAt` (Date, required, optional=NO)
   - `updatedAt` (Date, required, optional=NO)

3. **Test**: Build project - should succeed
4. **Test**: DataModel should still open

### **Entity 4: UserAttendance (Complete Structure)**
1. **Add new entity**: `UserAttendance`
2. **Add ALL attributes**:
   - `attendanceStatus` (Integer 16, required, optional=NO)
   - `eventYear` (Integer 32, required, optional=NO)
   - `createdAt` (Date, required, optional=NO)
   - `updatedAt` (Date, required, optional=NO)

3. **Test**: Build project - should succeed
4. **Test**: DataModel should still open

---

## 🔗 **Step 4: Add ALL Relationships (Complete Structure)**

### **Band ↔ Event Relationship (One-to-Many):**
1. **Click on Band entity**
2. **Add relationship**: `events` (to-many, destination: Event)
3. **Set inverse name**: `band`
4. **Set deletion rule**: `Cascade`
5. **Set optional**: YES

### **Event ↔ Band Relationship (Many-to-One):**
1. **Click on Event entity**
2. **Add relationship**: `band` (to-one, destination: Band)
3. **Set inverse name**: `events`
4. **Set deletion rule**: `Nullify`
5. **Set optional**: NO

### **Band ↔ UserPriority Relationship (One-to-One):**
1. **Click on Band entity**
2. **Add relationship**: `userPriority` (to-one, destination: UserPriority)
3. **Set inverse name**: `band`
4. **Set deletion rule**: `Cascade`
5. **Set optional**: YES

### **UserPriority ↔ Band Relationship (One-to-One):**
1. **Click on UserPriority entity**
2. **Add relationship**: `band` (to-one, destination: Band)
3. **Set inverse name**: `userPriority`
4. **Set deletion rule**: `Nullify`
5. **Set optional**: NO

### **Event ↔ UserAttendance Relationship (One-to-One):**
1. **Click on Event entity**
2. **Add relationship**: `userAttendance` (to-one, destination: UserAttendance)
3. **Set inverse name**: `event`
4. **Set deletion rule**: `Cascade`
5. **Set optional**: YES

### **UserAttendance ↔ Event Relationship (One-to-One):**
1. **Click on UserAttendance entity**
2. **Add relationship**: `event` (to-one, destination: Event)
3. **Set inverse name**: `userAttendance`
4. **Set deletion rule**: `Nullify`
5. **Set optional**: NO

---

## 📊 **Complete Data Structure Reference**

### **Band Entity (13 attributes + 2 relationships):**
```
Core Info: bandName, country, genre, noteworthy, priorYears
All URLs: officialSite, imageUrl, youtube, metalArchives, wikipedia  
System: eventYear, createdAt, updatedAt
Links: → Events (one-to-many), → UserPriority (one-to-one)
```

### **Event Entity (13 attributes + 2 relationships):**
```
Schedule: location, date, day, startTime, endTime, eventType
URLs: descriptionUrl, eventImageUrl, notes
System: timeIndex, eventYear, createdAt, updatedAt
Links: → Band (many-to-one), → UserAttendance (one-to-one)
```

### **UserPriority Entity (4 attributes + 1 relationship):**
```
Data: priorityLevel (1=Must, 2=Might, 3=Won't), eventYear
System: createdAt, updatedAt
Links: → Band (one-to-one)
```

### **UserAttendance Entity (4 attributes + 1 relationship):**
```
Data: attendanceStatus (1=Will, 2=Attended, 3=Won't), eventYear
System: createdAt, updatedAt
Links: → Event (one-to-one)
```

---

## ⚠️ **IMPORTANT: Test After Each Addition**

### **Testing Protocol:**
1. **After each entity**: Build project (⌘+B)
2. **After each relationship**: Build project (⌘+B)
3. **After each attribute**: Build project (⌘+B)
4. **After each change**: Click on DataModel to verify it opens

### **If Something Breaks:**
- **Undo the last change** immediately
- **Identify what caused the issue**
- **Fix it before proceeding**
- **Don't add more complexity until it's stable**

---

## 🎯 **Step 5: Final Verification**

### **Complete Model Should Have:**
- **4 entities**: Band, Event, UserPriority, UserAttendance
- **Band**: 13 attributes + 2 relationships
- **Event**: 13 attributes + 2 relationships
- **UserPriority**: 4 attributes + 1 relationship
- **UserAttendance**: 4 attributes + 1 relationship
- **All relationships properly configured** with correct inverse names
- **Proper deletion rules** (Cascade for owned objects, Nullify for references)

### **Test Everything:**
1. **Build project**: Should succeed
2. **Open DataModel**: Should open without crashing
3. **Verify all entities**: Should see 4 entity boxes
4. **Check relationships**: Should see proper connections
5. **Verify attributes**: Should see all required fields

---

## 🚀 **Step 6: Activate Performance System**

Once the Core Data model is stable:

1. **Restore real files**:
   ```bash
   ./ACTIVATE_OPTIMIZED_PERFORMANCE.sh
   ```

2. **Test performance**: Should see 60fps scrolling
3. **Import CSV data**: Should work without issues

---

## 📋 **Troubleshooting**

### **If Xcode Crashes Again:**
- **Remove the last change** you made
- **Identify the problematic element**
- **Use simpler data types** (String instead of Date, etc.)
- **Build incrementally** - don't add too much at once

### **If Build Fails:**
- **Check error messages** carefully
- **Fix one issue at a time**
- **Don't proceed until build succeeds**

### **If DataModel Won't Open:**
- **Remove the entire DataModel.xcdatamodeld**
- **Start over from Step 2**
- **Add entities more slowly**

---

## 🎉 **Success Criteria**

You'll know you're done when:
- ✅ Xcode opens without crashing
- ✅ DataModel.xcdatamodeld opens in visual editor
- ✅ All 4 entities are visible with correct names
- ✅ All attributes are present (Band: 13, Event: 13, UserPriority: 4, UserAttendance: 4)
- ✅ All relationships are properly connected with correct inverse names
- ✅ Project builds successfully
- ✅ No Core Data errors in console

---

## 🚨 **Emergency Recovery**

If everything goes wrong:
```bash
# Remove Core Data completely
rm -rf DataModel.xcdatamodeld/
# Remove from project (in Xcode)
# Start over from beginning
```

---

**🎯 Start with Step 1: Verify Xcode works now!**

**📊 Then follow this COMPLETE structure exactly as outlined above!**
