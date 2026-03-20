# Yolo_v3_Tiny_AXI
Author:  **Nguyen Van Luu** - nluu1784@gmail.com
**Nguyen Thi Thuy Linh** - linh041203@gmail.com
  
  Name of Institute: **School of Electrical and Electronic Engineering (SEEE)-HUST**    

  Language: **Verilog, Python**

  Framework: **Keras, Pytorch**
  
  Tools: **Cadence Xcelium, Vivado**
# Introduction 
A systolic array is widely adopted in many deep
neural network accelerators due to their structured dataflow and
high parallelism. However, object detection models such as You
Only Look Once (YOLO) introduce multi-scale feature maps and
varying layer dimensions, which often lead to resource under
utilization due to unnecessary bubble cycles. Firstly, this work
proposes an enhanced systolic array architecture that integrates
an effective dataflow mapping strategy with a multi-pipeline
computing scheme to improve throughput. Secondly, a dynamic
data reuse strategy based on the amount of data processed
by each layer is introduced to reduce off-chip memory traffic.
Experiments on YOLOv3-tiny show that the proposed design
achieves an inference speed of 15.88 FPS and a throughput of
88.82 GOPS at a clock frequency of 230 MHz.
# ARCHITECTURE OF SYSTEM
![YOLO Tiny Architecture](images/block_diagram.png)
# Block design on Vivado
![YOLO Tiny Architecture](images/VIVADO.jpg)
# Performance & Power consumption and hardware ultilization
![YOLO Tiny Architecture](images/image.png)
# Layout of chip on ZCU104
![YOLO Tiny Architecture](images/layout.jpg)

