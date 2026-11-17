(() => {
  const source = "https://cdn.jsdelivr.net/npm/tesseract.js@6.0.1/dist/";
  let library;

  function loadLibrary() {
    library ??= new Promise((resolve, reject) => {
      const script = document.createElement("script");
      script.src = source + "tesseract.min.js";
      script.integrity = "sha384-r1ru3tcf6FhnCFR4B7pIFG+BhFF9LlFtz/P1y4pblWn3AGs9y3lBx5SKLNf4+rED";
      script.crossOrigin = "anonymous";
      script.onload = () => resolve(window.Tesseract);
      script.onerror = () => {
        script.remove();
        library = undefined;
        reject(new Error("No se pudo cargar el motor OCR."));
      };
      document.head.appendChild(script);
    });
    return library;
  }

  window.linkShieldRecognizeText = async (image) => {
    const tesseract = await loadLibrary();
    const worker = await tesseract.createWorker("eng", 1, {
      workerPath: source + "worker.min.js",
      corePath: "https://cdn.jsdelivr.net/npm/tesseract.js-core@6.0.0",
      langPath: "https://cdn.jsdelivr.net/npm/@tesseract.js-data/eng@1.0.0/4.0.0_best_int",
    });
    try {
      const { data } = await worker.recognize(new Blob([image]));
      return data.text;
    } finally {
      await worker.terminate();
    }
  };
})();
