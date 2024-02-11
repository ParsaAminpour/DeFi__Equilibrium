#include <stdio.h>
#include <stdlib.h>

int m;

int check(int *arr, int i, int k) {
    if (arr[i] == k) {
        check(arr, 0, k+1);
    }
    
    // if i reach the end of the numbers and he was disappointed
    if (i == m) {
        return k;
    }
    
    check(arr, i+1, k);
}

int main() {
    int n;
    scanf("%d", &n);
    
    m = n-2;
    
    int *arr = (int*) malloc((n-1) * sizeof(int));
    for(int i = 0; i < m; i++) scanf("%d", &arr[i]);
    
    int res = check(arr, 0, 1);
    
    printf("%d\n", res);
    return 0;
}