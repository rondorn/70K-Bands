# 📊 DATA STRUCTURE QUICK REFERENCE

## 🎯 **Complete Core Data Model Structure**

### **Band Entity (13 attributes + 2 relationships)**
```
Core Info:
├── bandName (String, required)
├── country (String, optional)
├── genre (String, optional)
├── noteworthy (String, optional)
└── priorYears (String, optional)

All URLs:
├── officialSite (String, optional)
├── imageUrl (String, optional)
├── youtube (String, optional)
├── metalArchives (String, optional)
└── wikipedia (String, optional)

System:
├── eventYear (Integer 32, required)
├── createdAt (Date, required)
└── updatedAt (Date, required)

Relationships:
├── events → Event (one-to-many, optional=YES, Cascade)
└── userPriority → UserPriority (one-to-one, optional=YES, Cascade)
```

### **Event Entity (13 attributes + 2 relationships)**
```
Schedule:
├── location (String, optional)
├── date (String, optional)
├── day (String, optional)
├── startTime (String, optional)
├── endTime (String, optional)
└── eventType (String, optional)

URLs & Notes:
├── descriptionUrl (String, optional)
├── eventImageUrl (String, optional)
└── notes (String, optional)

System:
├── timeIndex (Double, required)
├── eventYear (Integer 32, required)
├── createdAt (Date, required)
└── updatedAt (Date, required)

Relationships:
├── band → Band (many-to-one, optional=NO, Nullify)
└── userAttendance → UserAttendance (one-to-one, optional=YES, Cascade)
```

### **UserPriority Entity (4 attributes + 1 relationship)**
```
Data:
├── priorityLevel (Integer 16, required)
└── eventYear (Integer 32, required)

System:
├── createdAt (Date, required)
└── updatedAt (Date, required)

Relationships:
└── band → Band (one-to-one, optional=NO, Nullify)
```

### **UserAttendance Entity (4 attributes + 1 relationship)**
```
Data:
├── attendanceStatus (Integer 16, required)
└── eventYear (Integer 32, required)

System:
├── createdAt (Date, required)
└── updatedAt (Date, required)

Relationships:
└── event → Event (one-to-one, optional=NO, Nullify)
```

---

## 🔗 **Relationship Rules**

### **Deletion Rules:**
- **Cascade**: When parent is deleted, child is deleted (owned objects)
- **Nullify**: When parent is deleted, child's reference is set to nil (references)

### **Optional Settings:**
- **Required relationships**: Set optional=NO (must have a value)
- **Optional relationships**: Set optional=YES (can be nil)

---

## 📱 **Build & Test Checklist**

### **After Each Entity:**
- [ ] Build project (⌘+B)
- [ ] DataModel opens without crashing
- [ ] Entity visible in visual editor

### **After Each Relationship:**
- [ ] Build project (⌘+B)
- [ ] DataModel opens without crashing
- [ ] Relationship visible and properly connected

### **Final Verification:**
- [ ] All 4 entities visible
- [ ] All attributes present (Band: 13, Event: 13, UserPriority: 4, UserAttendance: 4)
- [ ] All relationships properly connected
- [ ] Project builds successfully
- [ ] No Core Data errors

---

## 🚨 **Common Issues & Fixes**

### **If Build Fails:**
- Check attribute types (String, Integer 32, Integer 16, Double, Date)
- Verify relationship destinations exist
- Check inverse names match exactly

### **If DataModel Won't Open:**
- Remove last change immediately
- Build project to verify it works
- Add complexity more slowly

### **If Relationships Break:**
- Verify both entities exist
- Check inverse names match
- Ensure deletion rules are valid

---

**🎯 Use this reference while following the MANUAL_COREDATA_REBUILD_GUIDE.md**
