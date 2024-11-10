FROM ollama/ollama:0.3.2

RUN apt-get update && \
  apt-get install -y curl jq && \
  apt-get clean

COPY start_ollama.sh /usr/local/bin/start_ollama.sh
RUN chmod +x /usr/local/bin/start_ollama.sh

RUN /usr/local/bin/start_ollama.sh && ollama pull llama3.2
COPY script.sh /usr/local/bin/run_script.sh
RUN chmod +x /usr/local/bin/run_script.sh

ENTRYPOINT ["/usr/local/bin/run_script.sh"]
