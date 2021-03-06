#include "spmv.h"
#include <stdio.h>
#include <sys/time.h>

int main()
{
        printf("\n============================== TEST: SPARSE MATRIX GENERATOR ==============================\n\n");


        double p_diag = 0.9;
        double p_nondiag = 0.1;
        float *A;
        int *IA, *JA;
        int NNZ;

        // seed random number generator
        time_t t; srand((unsigned) time(&t));

        // For timing
        struct timeval t1, t2;
        double elapsedTime;
        
        int N;
        for (N = 2; N <= (1 << 15); N*=2)
        {

                gettimeofday(&t1, NULL);

                // allocates and changes A, IA, JA, & NNZ!
                generateSquareSpMatrix(&A, &IA, &JA, &NNZ, N, p_diag, p_nondiag);
                //printSpMatrix(A, IA, JA, N, N);

                gettimeofday(&t2, NULL);

                elapsedTime = (t2.tv_sec - t1.tv_sec) * 1000.0;      // sec to ms
                elapsedTime += (t2.tv_usec - t1.tv_usec) / 1000.0;   // us to ms

                printf("Successfully generated %ix%i sparse matrix in %g ms\n", N, N, elapsedTime);

                // Free memory
                free(A);
                free(IA);
                free(JA);
        }

        printf("\n===========================================================================================\n\n");
        return 0;
}
