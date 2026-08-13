## Database Setup

### 1. Create the Database

Open pgAdmin and create the database.

** 1.1. pgAdmin (GUI):**

1. Right-click **Databases** → **Create** → **Database**
2. Enter the name: `dreamhomes_nyc`
3. Click **Save**

```

### 1.2. Run the DDL Script to Create Tables

After connecting to the `dreamhomes_nyc` database, run the DDL script to create all 25 tables.

> **Note:** Replace `<path-to-repo>` below with the actual location where you saved this project on your machine.

**MpgAdmin:**

1. Expand the left panel → `dreamhomes_nyc` → right-click → **Query Tool**
2. Open the file `<path-to-repo>\dreamhomes_ddl_v2.sql`
3. Click **▶ Execute**
4. A "Query returned successfully" message confirms it worked

