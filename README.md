# 📦 Handling Compliance Analysis (SQL)

This project analyzes whether items are handled according to expected rules by comparing **expected handling (based on item size)** vs **actual handling (based on text descriptions)**.

It demonstrates how structured and unstructured data can be combined to evaluate operational consistency.

---

# 🎯 Objective

To determine:

* how items *should* be handled (based on size/dimensions)
* how items are *actually* handled (based on comments/text)
* whether the handling process follows expected standards

---

# 🧠 Key Idea

This project combines:

* **structured data** → item dimensions
* **unstructured data** → text comments
* **rule-based logic** → classification

to produce a **compliance evaluation system**.

---

# 🔗 Data Pipeline

```text
Raw Operational Data
        ↓
SQL Transformation (this project)
        ↓
Expected vs Actual Comparison
        ↓
Compliance Classification
        ↓
BI Dashboard / Reporting
```

---

# ⚙️ What This Query Does

The query:

✅ extracts recent records
✅ joins multiple datasets
✅ detects keywords from text comments
✅ classifies items based on size
✅ compares expected vs actual handling
✅ assigns a compliance status

---

# 📊 Output Columns

| Column               | Description                     |
| -------------------- | ------------------------------- |
| order_id             | Unique item/order ID            |
| process_datetime     | Timestamp of processing         |
| origin_location      | Origin location                 |
| destination_location | Destination                     |
| expected_handling    | Handling based on size          |
| actual_handling      | Handling inferred from comments |
| compliance_status    | Result of comparison            |
| high_value_flag      | High value indicator            |
| business_flag        | Business-related indicator      |

---

# 🗂 Dataset Overview

All datasets are anonymized for confidentiality.

---

## dataset_orders

Represents item or shipment records.

| Column               | Description          |
| -------------------- | -------------------- |
| order_id             | Unique ID            |
| origin_location      | Source               |
| destination_location | Destination          |
| process_datetime     | Processing timestamp |
| comments             | Free text notes      |

---

## dataset_item_attributes

Item-level attributes including dimensions.

| Column                      | Description        |
| --------------------------- | ------------------ |
| order_id                    | Unique ID          |
| tracking_id                 | Tracking reference |
| dim_length / width / height | Item dimensions    |

---

## dataset_tags

Categorical labels applied to items.

| Column   | Description |
| -------- | ----------- |
| order_id | Unique ID   |
| tag_name | Tag label   |

---

# 🧪 Classification Logic

### Expected Handling

* Based on item dimensions
* Smaller items → boxed
* Larger items → wrapped

### Actual Handling

* Extracted from text comments using keyword detection

### Compliance Rules

| Case                        | Result               |
| --------------------------- | -------------------- |
| expected = actual           | compliant            |
| actual exists but different | alternative_handling |
| no clear handling           | non_compliant        |

---

# 🚀 Why This Project Matters

This project demonstrates:

* SQL for real-world decision logic
* text analysis using regex
* combining structured + unstructured data
* rule-based classification systems
* building datasets for BI dashboards

---

# 🛠 Tech Stack

* SQL (Presto / Trino compatible)
* Data warehouse
* BI tools

---

# 📁 Project Structure

```text
handling-compliance-analysis
│
├── sql
│   └── handling_compliance_analysis.sql
│
└── README.md
```

---

# 📜 License

MIT
