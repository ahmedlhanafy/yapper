// Swift-friendly shim for whisper.cpp
// Provides helper functions for easier Swift interop

#ifndef WHISPER_SHIM_H
#define WHISPER_SHIM_H

#include "whisper.h"

#ifdef __cplusplus
extern "C" {
#endif

// Helper to check if library is available
static inline int whisper_is_available(void) {
    return 1; // Return 1 if whisper.cpp is properly linked
}

// Helper to get error string
static inline const char * whisper_get_last_error(void) {
    return "Whisper operation failed";
}

#ifdef __cplusplus
}
#endif

#endif // WHISPER_SHIM_H
