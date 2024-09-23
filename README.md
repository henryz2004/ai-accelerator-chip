# AI Accelerator Chip
This chip uses a tiled architecture to compute a series of fixed-point multiply-and-accumulate operations in parallel. In other words, the chip takes a vector and performs a series of matrix multiplications to it, which simulates layer computations in Deep Learning.

## Architecture
The tiled architecture refers to the chip being composed of a grid of autonomous tiles, each tile connected to adjacent tiles. Each tile is analogous to an artificial neuron in Deep Learning. Information propagates from top to bottom, with the input vector being passed into the top layer of the grid and subsequent results being passed downwards to the next layer. The final result is the output from the bottom layer of the grid. The tiles communicate bidirectionally with its left/right neighbors to assemble the output of the entire layer, which is then propagated downwards as the input of the next neuron.

### Core
![core](https://github.com/user-attachments/assets/7b95760c-ad53-4149-a95a-9523511c9951 | width=300)

Within each tile is an outer and inner core. The inner core computes the dot product of the input vector with its weight vector, which computes the output of one neuron. The inner core sends the result to the outer core, which communicates with the tile's neighbors to assemble the entire layer's output. The output of the outer core is the output of an entire layer.

### Tile
![tile](https://github.com/user-attachments/assets/f79e64b1-447e-4610-b977-9152285abb6a)

The tile is a wrapper module for the outer core, which handles serial communication and daisy-chaining with neighboring tiles.

### Communication
![communication](https://github.com/user-attachments/assets/e84fdda9-44a4-4e8d-815a-24957a629c1b)

Communication happens in a daisy-chained manner, with each tile sending its own output as well as any outputs it receives from its neighbors. This allows the output of a single neuron to propogate to all of the other neurons in the layer, so that each tile can output the result of the layer to the next tile. This is necessary as each tile expects an entire vector (the output of the previous layer) as input.

## Simulation
![simulation](https://github.com/user-attachments/assets/777a461a-29c3-47b6-b213-9c8971cac383)

This project was built with Intel Quartus and simulated with ModelSim. Each module has appropriate testbenches to ensure the correctness of the components. The`outer_core_tb` simulates a 4x4 grid of cores using non-serial communication. In the screenshot of the waveform simulation, the outputs of the last layer (`/outer_tb/layer_outg[3]`) are consistent with the expected results.
