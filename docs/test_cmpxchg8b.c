#include <stdio.h>
#include <stdint.h>

int main() {
    volatile uint64_t val = 0;
    uint64_t old = 0;
    uint64_t new = 1;

    uint64_t result = __sync_val_compare_and_swap(&val, old, new);

    printf("Result: %llu\n", (unsigned long long)result);
    printf("Val now: %llu\n", (unsigned long long)val);

    return 0;
}
