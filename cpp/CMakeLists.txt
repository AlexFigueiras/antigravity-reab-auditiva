cmake_minimum_required(VERSION 3.22.1)
project(dsp_audio_engine)

# Injeta a biblioteca do Google Oboe via FetchContent
include(FetchContent)
FetchContent_Declare(
    oboe
    GIT_REPOSITORY https://github.com/google/oboe.git
    GIT_TAG        1.8.1
)
FetchContent_MakeAvailable(oboe)

# Configuração C++17 para bibliotecas modernas
set(CMAKE_CXX_STANDARD 17)

# Adiciona a biblioteca compartilhada (JNI/FFI)
add_library(dsp_audio_engine SHARED
    native_bridge.cpp
    dsp_engine.cpp
    oboe_engine.cpp
    fir_filter.cpp
)

# Pesquisa pela biblioteca de log do Android
find_library(log-lib log)

# Vincula as bibliotecas necessárias para o Motor Biônico
target_link_libraries(dsp_audio_engine
    PRIVATE
    ${log-lib}
    android
    oboe
)
