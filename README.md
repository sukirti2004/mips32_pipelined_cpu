# 🧠 MIPS32 Pipelined Processor (Verilog)

This repository contains the implementation of a **MIPS32 pipelined processor** written in **Verilog HDL**. The design focuses on classic pipeline concepts, hazard handling, and performance optimization techniques commonly taught in computer architecture.

---

## 📌 Overview

The processor follows a **5-stage pipelined architecture**, enabling parallel instruction execution and improved throughput. Several hardware mechanisms are implemented to correctly handle pipeline hazards while maintaining performance.

---

## ⚙️ Features

### ✅ Implemented

* **5-Stage Pipeline Architecture**

  * Instruction Fetch (IF)
  * Instruction Decode (ID)
  * Execute (EX)
  * Memory Access (MEM)
  * Write Back (WB)

* **Pipeline Registers**

  * IF/ID
  * ID/EX
  * EX/MEM
  * MEM/WB

* **Data Hazard Handling**

  * Data forwarding (bypassing) unit
  * Reduces unnecessary pipeline stalls

* **Control Hazard Handling**

  * Control hazard mitigation logic (e.g., flushing/stalling)
  * Ensures correct execution of branch instructions

* **Modular Verilog Design**

  * Clean separation of datapath, control unit, and hazard units
  * Easy to extend and debug

---

## 🛠️ Technologies Used

* **Language:** Verilog HDL
* **Architecture:** MIPS32
* **Design Style:** RTL, modular pipeline-based design

---

## 🚀 Future Work

Planned enhancements for upcoming versions include:

* 🧩 **L1 Cache Integration**

  * Instruction Cache (I-Cache)
  * Data Cache (D-Cache)
  * Cache controller and memory interface

* 📈 Performance analysis and benchmarking

* 🧪 Extended instruction set support

* 🧠 Improved branch handling (e.g., branch prediction)

---

## 📖 References

* *Computer Organization and Design – Patterson & Hennessy*
* MIPS32 Architecture Documentation

---


