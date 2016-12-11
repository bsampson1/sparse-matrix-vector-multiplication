#include "spmv.h"
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <sys/time.h>

int main()
{
        printf("\n============================== TEST: SPMV TIMING ==========================================\n\n");

        // PARAMETERS
        double p_diag = 0.9;
        double p_nondiag = 0.1;
        float *A_cpu, *A_gpu, *x_cpu, *x_gpu, *y_cpu, *y_gpu, *y_correct;
        int *IA_cpu, *IA_gpu, *JA_cpu, *JA_gpu;
        int NNZ;

        int expNmin = 10;
        int expNmax = 15;
        int Nmin = (1 << expNmin);
        int Nmax = (1 << expNmax);
        int L = expNmax-expNmin+1; //printf("L = %i\n", L);
        float *t_arr = (float *)malloc(sizeof(float)*L);
        int *N_arr = (int *)malloc(sizeof(float)*L);
        int i; int idx = 0;
        for (i = 0; i < L; ++i)
                N_arr[i] = (1 << (i+expNmin));

        // seed random number generator
        time_t t; srand((unsigned) time(&t));

        const int NUM_ITERS = 1;

        // Define cuda events for GPU timing
        float milliseconds;
        cudaEvent_t start, stop;
        cudaEventCreate(&start);
        cudaEventCreate(&stop);

        // Setup CPU timing for cpuSpMV
        //struct timeval t1, t2;
        
        int N, iter; double elapsed;
        for (N = Nmin; N <= Nmax; N=N*2)
        {
                elapsed = 0;
                for (iter = 0; iter < NUM_ITERS; ++iter)
                {
                        // Create sparse matrix
                        generateSquareSpMatrix(&A_cpu, &IA_cpu, &JA_cpu, &NNZ, N, p_diag, p_nondiag); // allocates!

                        // Generate dense vector x
                        x_cpu = (float *)malloc(sizeof(float)*N);
                        fillDenseVector(x_cpu, N);
                        
                        // Define output vector y and y_correct
                        y_cpu = (float *)malloc(sizeof(float)*N);
                        y_correct = (float *)malloc(sizeof(float)*N);

                        // Setup memory on the GPU
                        cudaMalloc((void**) &A_gpu, NNZ*sizeof(float));
                        cudaMalloc((void**) &IA_gpu, (N+1)*sizeof(int)); // N = M
                        cudaMalloc((void**) &JA_gpu, NNZ*sizeof(int));
                        cudaMalloc((void**) &x_gpu, N*sizeof(float));
                        cudaMalloc((void**) &y_gpu, N*sizeof(float)); // N = M
        
                        // Transfer to device
                        cudaMemcpy(A_gpu, A_cpu, NNZ*sizeof(float), cudaMemcpyHostToDevice);
                        cudaMemcpy(IA_gpu, IA_cpu, (N+1)*sizeof(int), cudaMemcpyHostToDevice);
                        cudaMemcpy(JA_gpu, JA_cpu, NNZ*sizeof(int), cudaMemcpyHostToDevice);
                        cudaMemcpy(x_gpu, x_cpu, N*sizeof(float), cudaMemcpyHostToDevice);
                        
                        // CUDA kernel parameters
                        //int sMem = (1 << 15);
                        int dB, dG;
                        if (N < 1024)
                        {
                                dB = N;
                                dG = 1;
                        }
                        else
                        {
                                dB = BLOCK_SIZE;
                                dG = N / 1024;
                        }
                        
                        // Do CPU timing
                        //gettimeofday(&t1, NULL);
                        //cpuSpMV(y_cpu, A_cpu, IA_cpu, JA_cpu, N, x_cpu);
                        //gettimeofday(&t2, NULL);
                        //elapsed += (t2.tv_sec-t1.tv_sec)*1000.0 + (t2.tv_usec-t1.tv_usec)/1000.0; // in ms

                        // Start cudaEvent timing
                        cudaEventRecord(start);
                        
                        // CUDA Vanilla SpMV Kernel
                        //spmvVanilla<<<dG, dB>>>(y_gpu, A_gpu, IA_gpu, JA_gpu, x_gpu);

                        // CUDA Chocolate SpMV Kernel
                        spmvChocolate<<<dG, dB>>>(y_gpu, A_gpu, IA_gpu, JA_gpu, x_gpu);
                       
                        // Stop cudaEvent timing
                        cudaEventRecord(stop);
                        cudaEventSynchronize(stop);

                        // Check to make sure that cuda kernel was successful
                        cudaError_t err = cudaGetLastError();
                        if (err != cudaSuccess)
                                printf("Error: %s\n", cudaGetErrorString(err));

                        // Record timing result
                        milliseconds = 0;
                        cudaEventElapsedTime(&milliseconds, start, stop);
                        elapsed += milliseconds;

                        // Transfer result back to host
                        cudaMemcpy(y_cpu, y_gpu, N*sizeof(float), cudaMemcpyDeviceToHost);

                        // Test correctness of CUDA kernel vs "golden" cpu spmv function
                        cpuSpMV(y_correct, A_cpu, IA_cpu, JA_cpu, N, x_cpu);
                        if (!areEqualRMSE(y_correct, y_cpu, N))
                                printf("Not correct result for a (%ix%i)*(%ix1) spmv multiplication\n", N, N, N);

                        // Free memory
                        free(A_cpu);
                        free(IA_cpu);
                        free(JA_cpu);
                        free(x_cpu);
                        free(y_cpu);
                        free(y_correct);
                        cudaFree(A_gpu);
                        cudaFree(IA_gpu);
                        cudaFree(JA_gpu);
                        cudaFree(x_gpu);
                        cudaFree(y_gpu);
                }
                t_arr[idx++] = (float)elapsed/NUM_ITERS;
        }

        printf("Results averaged over %i iterations with time in ms:\n", NUM_ITERS);
        printf("N = "); printArray(N_arr, L);
        printf("t = "); printArray(t_arr, L);
        
        free(t_arr);
        free(N_arr);

        cudaDeviceReset();
	
        
        printf("\n===========================================================================================\n\n");

        return 0;
}