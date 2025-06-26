#!/bin/bash
if [ -n "${MODEL_CHAT_FORMAT}" ]; then

    # handle the case of llama.cpp python chat format
    if [ "${MODEL_CHAT_FORMAT}" = "llama-2" ]; then
        MODEL_CHAT_FORMAT="llama2"
    fi
    CHAT_FORMAT="--chat_template ${MODEL_CHAT_FORMAT}"
fi

# apply --jinja flag if MODEL_JINJA is set
if [ -n "${MODEL_JINJA}" ]; then
    CHAT_FORMAT="${CHAT_FORMAT} --jinja"
fi

if [ -z "${MODEL_PATH}" ]; then
    MODEL_PATH="/mnt/models/model.file"
fi
if [ -n "${CTX_SIZE}" ]; then
    CTX_SIZE_FLAG="--ctx_size ${CTX_SIZE}"
fi
eval llama-server \
     --model "${MODEL_PATH}" \
     --host "${HOST:=0.0.0.0}" \
     --port "${PORT:=8001}" \
     --gpu_layers "${GPU_LAYERS:=0}" \
     "${CTX_SIZE_FLAG:=""}" \
     "${CHAT_FORMAT}"
exit 0