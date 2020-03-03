#include "darknet.h"
#include <cuda_runtime.h>
#include <curand.h>
#include <cublas_v2.h>

#include "activations.h"
#include "dark_cuda.h"


__device__ float lhtan_activate_kernel(float x)
{
    if(x < 0) return .001*x;
    if(x > 1) return .001*(x-1) + 1;
    return x;
}
__device__ float lhtan_gradient_kernel(float x)
{
    if(x > 0 && x < 1) return 1;
    return .001;
}

__device__ float hardtan_activate_kernel(float x)
{
    if (x < -1) return -1;
    if (x > 1) return 1;
    return x;
}
__device__ float linear_activate_kernel(float x){return x;}
__device__ float logistic_activate_kernel(float x){return 1.f/(1.f + expf(-x));}
__device__ float loggy_activate_kernel(float x){return 2.f/(1.f + expf(-x)) - 1;}
__device__ float relu_activate_kernel(float x){return x*(x>0);}
__device__ float elu_activate_kernel(float x){return (x >= 0)*x + (x < 0)*(expf(x)-1);}
__device__ float selu_activate_kernel(float x) { return (x >= 0)*1.0507f*x + (x < 0)*1.0507f*1.6732f*(expf(x) - 1); }
__device__ float relie_activate_kernel(float x){return (x>0) ? x : .01f*x;}
__device__ float ramp_activate_kernel(float x){return x*(x>0)+.1f*x;}
__device__ float leaky_activate_kernel(float x){return (x>0) ? x : .1f*x;}
__device__ float tanh_activate_kernel(float x){return (2/(1 + expf(-2*x)) - 1);}
__device__ float plse_activate_kernel(float x)
{
    if(x < -4) return .01f * (x + 4);
    if(x > 4)  return .01f * (x - 4) + 1;
    return .125f*x + .5f;
}
__device__ float stair_activate_kernel(float x)
{
    int n = floorf(x);
    if (n%2 == 0) return floorf(x/2.f);
    else return (x - n) + floorf(x/2.f);
}


__device__ float hardtan_gradient_kernel(float x)
{
    if (x > -1 && x < 1) return 1;
    return 0;
}
__device__ float linear_gradient_kernel(float x){return 1;}
__device__ float logistic_gradient_kernel(float x){return (1-x)*x;}
__device__ float loggy_gradient_kernel(float x)
{
    float y = (x+1.F)/2.F;
    return 2*(1-y)*y;
}
__device__ float relu_gradient_kernel(float x){return (x>0);}
__device__ float elu_gradient_kernel(float x){return (x >= 0) + (x < 0)*(x + 1);}
__device__ float selu_gradient_kernel(float x) { return (x >= 0)*1.0507f + (x < 0)*(x + 1.0507f*1.6732f); }
__device__ float relie_gradient_kernel(float x){return (x>0) ? 1 : .01f;}
__device__ float ramp_gradient_kernel(float x){return (x>0)+.1f;}
__device__ float leaky_gradient_kernel(float x){return (x>0) ? 1 : .1f;}
__device__ float tanh_gradient_kernel(float x){return 1-x*x;}
__device__ float plse_gradient_kernel(float x){return (x < 0 || x > 1) ? .01f : .125f;}
__device__ float stair_gradient_kernel(float x)
{
    if (floor(x) == x) return 0;
    return 1;
}

__device__ float activate_kernel(float x, ACTIVATION a)
{
    switch(a){
        case LINEAR:
            return linear_activate_kernel(x);
        case LOGISTIC:
            return logistic_activate_kernel(x);
        case LOGGY:
            return loggy_activate_kernel(x);
        case RELU:
            return relu_activate_kernel(x);
        case ELU:
            return elu_activate_kernel(x);
        case SELU:
            return selu_activate_kernel(x);
        case RELIE:
            return relie_activate_kernel(x);
        case RAMP:
            return ramp_activate_kernel(x);
        case LEAKY:
            return leaky_activate_kernel(x);
        case TANH:
            return tanh_activate_kernel(x);
        case PLSE:
            return plse_activate_kernel(x);
        case STAIR:
            return stair_activate_kernel(x);
        case HARDTAN:
            return hardtan_activate_kernel(x);
        case LHTAN:
            return lhtan_activate_kernel(x);
    }
    return 0;
}

__device__ float gradient_kernel(float x, ACTIVATION a)
{
    switch (a) {
    case LINEAR:
        return linear_gradient_kernel(x);
    case LOGISTIC:
        return logistic_gradient_kernel(x);
    case LOGGY:
        return loggy_gradient_kernel(x);
    case RELU:
        return relu_gradient_kernel(x);
    case ELU:
        return elu_gradient_kernel(x);
    case SELU:
        return selu_gradient_kernel(x);
    case RELIE:
        return relie_gradient_kernel(x);
    case RAMP:
        return ramp_gradient_kernel(x);
    case LEAKY:
        return leaky_gradient_kernel(x);
    case TANH:
        return tanh_gradient_kernel(x);
    case PLSE:
        return plse_gradient_kernel(x);
    case STAIR:
        return stair_gradient_kernel(x);
    case HARDTAN:
        return hardtan_gradient_kernel(x);
    case LHTAN:
        return lhtan_gradient_kernel(x);
    }
    return 0;
}

__global__ void binary_gradient_array_kernel(float *x, float *dy, int n, int s, BINARY_ACTIVATION a, float *dx)
{
    int id = (blockIdx.x + blockIdx.y*gridDim.x) * blockDim.x + threadIdx.x;
    int i = id % s;
    int b = id / s;
    float x1 = x[b*s + i];
    float x2 = x[b*s + s / 2 + i];
    if (id < n) {
        float de = dy[id];
        dx[b*s + i] = x2*de;
        dx[b*s + s / 2 + i] = x1*de;
    }
}

extern "C" void binary_gradient_array_gpu(float *x, float *dx, int n, int size, BINARY_ACTIVATION a, float *y)
{
    binary_gradient_array_kernel << <cuda_gridsize(n / 2), BLOCK, 0, get_cuda_stream() >> >(x, dx, n / 2, size, a, y);
    CHECK_CUDA(cudaPeekAtLastError());
}
__global__ void binary_activate_array_kernel(float *x, int n, int s, BINARY_ACTIVATION a, float *y)
{
    int id = (blockIdx.x + blockIdx.y*gridDim.x) * blockDim.x + threadIdx.x;
    int i = id % s;
    int b = id / s;
    float x1 = x[b*s + i];
    float x2 = x[b*s + s / 2 + i];
    if (id < n) y[id] = x1*x2;
}

extern "C" void binary_activate_array_gpu(float *x, int n, int size, BINARY_ACTIVATION a, float *y)
{
    binary_activate_array_kernel << <cuda_gridsize(n / 2), BLOCK, 0, get_cuda_stream() >> >(x, n / 2, size, a, y);
    CHECK_CUDA(cudaPeekAtLastError());
}

__global__ void activate_array_kernel(float *x, int n, ACTIVATION a)
{
    int i = (blockIdx.x + blockIdx.y*gridDim.x) * blockDim.x + threadIdx.x;
    if(i < n) x[i] = activate_kernel(x[i], a);
}



__global__ void activate_array_swish_kernel(float *x, int n, float *output_sigmoid_gpu, float *output_gpu)
{
    int i = (blockIdx.x + blockIdx.y*gridDim.x) * blockDim.x + threadIdx.x;
    if (i < n) {
        float x_val = x[i];
        float sigmoid = logistic_activate_kernel(x_val);
        output_sigmoid_gpu[i] = sigmoid;
        output_gpu[i] = x_val * sigmoid;
    }
}

__global__ void activate_array_leaky_kernel(float *x, int n)
{
    int index = blockIdx.x*blockDim.x + threadIdx.x;
    if (index < n) {
        x[index] = leaky_activate_kernel(x[index]);
    }
}

__global__ void activate_array_selu_kernel(float *x, int n)
{
    int index = blockIdx.x*blockDim.x + threadIdx.x;
    if (index < n) {
        x[index] = selu_activate_kernel(x[index]);
    }
}

__global__ void activate_array_logistic_kernel(float *x, int n)
{
    int index = blockIdx.x*blockDim.x + threadIdx.x;
    if (index < n) {
        x[index] = logistic_activate_kernel(x[index]);
    }
}

__global__ void activate_array_tanh_kernel(float *x, int n)
{
    int index = blockIdx.x*blockDim.x + threadIdx.x;
    if (index < n) {
        x[index] = tanh_activate_kernel(x[index]);
    }
}

__global__ void activate_array_hardtan_kernel(float *x, int n)
{
    int index = blockIdx.x*blockDim.x + threadIdx.x;
    if (index < n) {
        x[index] = hardtan_activate_kernel(x[index]);
    }
}

__global__ void activate_array_relu_kernel(float *x, int n)
{
    int index = blockIdx.x*blockDim.x + threadIdx.x;
    if (index < n) {
        x[index] = relu_activate_kernel(x[index]);
    }
}

__global__ void gradient_array_kernel(float *x, int n, ACTIVATION a, float *delta)
{
    int i = (blockIdx.x + blockIdx.y*gridDim.x) * blockDim.x + threadIdx.x;
    if(i < n) delta[i] *= gradient_kernel(x[i], a);
}

// https://github.com/BVLC/caffe/blob/04ab089db018a292ae48d51732dd6c66766b36b6/src/caffe/layers/swish_layer.cu#L28-L30
__global__ void gradient_array_swish_kernel(float *x, int n, float *sigmoid_gpu, float *delta)
{
    int i = (blockIdx.x + blockIdx.y*gridDim.x) * blockDim.x + threadIdx.x;
    if (i < n) {
        float swish = x[i];
        delta[i] *= swish + sigmoid_gpu[i] * (1 - swish); // gradient_kernel(x[i], a);
    }
}

__global__ void gradient_array_leaky_kernel(float *x, int n, float *delta)
{
    int index = blockIdx.x*blockDim.x + threadIdx.x;
    if (index < n) {
        delta[index] *= leaky_gradient_kernel(x[index]);
    }
}

__global__ void gradient_array_selu_kernel(float *x, int n, float *delta)
{
    int index = blockIdx.x*blockDim.x + threadIdx.x;
    if (index < n) {
        delta[index] *= selu_gradient_kernel(x[index]);
    }
}

__global__ void gradient_array_logistic_kernel(float *x, int n, float *delta)
{
    int index = blockIdx.x*blockDim.x + threadIdx.x;
    if (index < n) {
        delta[index] *= logistic_gradient_kernel(x[index]);
    }
}

__global__ void gradient_array_tanh_kernel(float *x, int n, float *delta)
{
    int index = blockIdx.x*blockDim.x + threadIdx.x;
    if (index < n) {
        delta[index] *= tanh_gradient_kernel(x[index]);
    }
}

__global__ void gradient_array_hardtan_kernel(float *x, int n, float *delta)
{
    int index = blockIdx.x*blockDim.x + threadIdx.x;
    if (index < n) {
        delta[index] *= hardtan_gradient_kernel(x[index]);
    }
}

__global__ void gradient_array_relu_kernel(float *x, int n, float *delta)
{
    int index = blockIdx.x*blockDim.x + threadIdx.x;
    if (index < n) {
        delta[index] *= relu_gradient_kernel(x[index]);
    }
}

extern "C" void activate_array_ongpu(float *x, int n, ACTIVATION a)
{
    const int num_blocks = get_number_of_blocks(n, BLOCK);
    if (a == LINEAR) return;
    else if(a == LEAKY) activate_array_leaky_kernel << <num_blocks, BLOCK, 0, get_cuda_stream() >> >(x, n);
    else if (a == LOGISTIC) activate_array_logistic_kernel << <num_blocks, BLOCK, 0, get_cuda_stream() >> >(x, n);
    else if (a == TANH) activate_array_tanh_kernel << <num_blocks, BLOCK, 0, get_cuda_stream() >> >(x, n);
    else if (a == HARDTAN) activate_array_hardtan_kernel << <num_blocks, BLOCK, 0, get_cuda_stream() >> >(x, n);
    else if (a == RELU) activate_array_relu_kernel << <num_blocks, BLOCK, 0, get_cuda_stream() >> >(x, n);
    else if (a == SELU) activate_array_selu_kernel << <num_blocks, BLOCK, 0, get_cuda_stream() >> >(x, n);
    else
        activate_array_kernel<<<cuda_gridsize(n), BLOCK, 0, get_cuda_stream()>>>(x, n, a);
    CHECK_CUDA(cudaPeekAtLastError());
}

extern "C" void activate_array_swish_ongpu(float *x, int n, float *output_sigmoid_gpu, float *output_gpu)
{
    const int num_blocks = get_number_of_blocks(n, BLOCK);
    activate_array_swish_kernel << <cuda_gridsize(n), BLOCK, 0, get_cuda_stream() >> >(x, n, output_sigmoid_gpu, output_gpu);
    CHECK_CUDA(cudaPeekAtLastError());
}

extern "C" void gradient_array_ongpu(float *x, int n, ACTIVATION a, float *delta)
{
    const int num_blocks = get_number_of_blocks(n, BLOCK);
    if (a == LINEAR) return;
    else if (a == LEAKY) gradient_array_leaky_kernel << <num_blocks, BLOCK, 0, get_cuda_stream() >> >(x, n, delta);
    else if (a == LOGISTIC) gradient_array_logistic_kernel << <num_blocks, BLOCK, 0, get_cuda_stream() >> >(x, n, delta);
    else if (a == TANH) gradient_array_tanh_kernel << <num_blocks, BLOCK, 0, get_cuda_stream() >> >(x, n, delta);
    else if (a == HARDTAN) gradient_array_hardtan_kernel << <num_blocks, BLOCK, 0, get_cuda_stream() >> >(x, n, delta);
    else if (a == RELU) gradient_array_relu_kernel << <num_blocks, BLOCK, 0, get_cuda_stream() >> >(x, n, delta);
    else if (a == SELU) gradient_array_selu_kernel << <num_blocks, BLOCK, 0, get_cuda_stream() >> >(x, n, delta);
    else
        gradient_array_kernel << <cuda_gridsize(n), BLOCK, 0, get_cuda_stream() >> > (x, n, a, delta);
    CHECK_CUDA(cudaPeekAtLastError());
}


extern "C" void gradient_array_swish_ongpu(float *x, int n, float *sigmoid_gpu, float *delta)
{
    const int num_blocks = get_number_of_blocks(n, BLOCK);
    gradient_array_swish_kernel << <cuda_gridsize(n), BLOCK, 0, get_cuda_stream() >> > (x, n, sigmoid_gpu, delta);
    CHECK_CUDA(cudaPeekAtLastError());
}