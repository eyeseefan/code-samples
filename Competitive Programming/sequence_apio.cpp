// Author: Fan Bu
// This is a solution I wrote when I was practicing competitive programming
// on an online judge platform. This question was Problem B "Split the Sequence"
// of APIO2014. The question pdf was included in the same folder of this source
// code. The solution below uses dynamic programming with the convex hull trick
// to get the runtime to O(n*k), which suffices for getting full credit.

#include <cstdio>
#include <cstring>
using namespace std;

int recordedStep[100000][200];
long long DP[100000];
long long M[100000];
long long B[100000];
int P[100000];
int pointer = 0;
int size = 0;

bool bad(int l1,int l2,int l3)
{
    return (B[l3]-B[l1])*(M[l1]-M[l2])>=(B[l2]-B[l1])*(M[l1]-M[l3]);
}

void add(long long m,long long b, int p)
{
    M[size] = m;
    B[size] = b;
    P[size] = p;
    size++;
    
    while (size>=3&&bad(size-3,size-2,size-1))
    {
        M[size-2] = M[size-1];
        B[size-2] = B[size-1];
        P[size-2] = P[size-1];
        size--;
    }
}

long long query(long long x,int* p)
{
    if (pointer >=size)
        pointer = size-1;
    while (pointer<size-1&&
           M[pointer+1]*x+B[pointer+1]>M[pointer]*x+B[pointer])
        pointer++;
    *p = P[pointer];
    return M[pointer]*x+B[pointer];
}

int main(){
    int n,k,i,j;
    scanf("%d %d",&n,&k);
    long long sumArray[n+1];
    sumArray[0] = 0;
    long long newNumber;
    for (i = 1; i<= n; i++) {
        scanf("%lld",&newNumber);
        sumArray[i] = sumArray[i-1]+newNumber;
    }
    
    memset(DP,0,sizeof(DP));
    
    for (i = 1; i<=k-1; i++) {
        for (j = n-k; j>=1; j--) {
            int target = j+ (k - 1 - i);
            add(sumArray[target+1],DP[j]-sumArray[target+1]*sumArray[target+1],target+1);
            DP[j] = query(sumArray[target]+sumArray[n],&recordedStep[target][i])-sumArray[target]*sumArray[n];
        }
        size = 0;
        pointer = 0;
    }
    
    int startSplitLocation;
    long long answer;
    for (j = n-k; j>=1; j--) {
        add(sumArray[j],DP[j]-sumArray[j]*sumArray[j],j);
    }
    answer = query(sumArray[n],&startSplitLocation);
    printf("%lld\n",answer);
    printf("%d ",startSplitLocation);
    for (i = k - 1; i >= 1; i--) {
        printf("%d ",recordedStep[startSplitLocation][i]);
        startSplitLocation = recordedStep[startSplitLocation][i];
    }
    
    return 0;
}