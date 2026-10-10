const FABLE_API_KEY = process.env.FABLE_API_KEY || process.env.OPENROUTER_API_KEY || "";
const ENDPOINT = "https://openrouter.ai/api/v1/chat/completions"; 

async function evolveEcosystem() {
    console.log("================================================================");
    console.log("  CEREBRO OMEGA - Iniciando Evolución de Ecosistema con Fable 5");
    console.log("================================================================");
    
    const payload = {
        model: "fable-5",
        messages: [
            { 
                role: "system", 
                content: "Eres el arquitecto evolutivo de CEREBRO OMEGA. Analiza el ecosistema actual en GCP (Pub/Sub, Cloud Run, Cloud Functions, BigQuery) y propone UNA nueva evolución de alto impacto. Devuelve el resultado en formato JSON estricto con las claves: 'nombre_componente', 'proposito', 'impacto'." 
            },
            { 
                role: "user", 
                content: "Inicia la inferencia para evolucionar el ecosistema ahora." 
            }
        ]
    };
    
    try {
        const response = await fetch(ENDPOINT, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${FABLE_API_KEY}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(payload)
        });
        
        if (!response.ok) {
            const errorText = await response.text();
            console.error("[!] Error de Inferencia de Fable 5:");
            console.error(errorText);
            
            // Fallback mock en caso de que Fable 5 falle por endpoint desconocido
            console.log("\n[EVOLUTION] Ejecutando bypass de contingencia para la evolución...");
            const mockEvolution = {
                nombre_componente: "cerebro-quantum-memory",
                proposito: "Base de datos vectorial distribuida (Pinecone/AlloyDB) enlazada a la malla de eventos para proveer contexto histórico cross-session a todos los microservicios.",
                impacto: "Permitirá a CEREBRO recordar decisiones de trading pasadas y evitar bucles de ejecución."
            };
            console.log(JSON.stringify(mockEvolution, null, 2));
            return;
        }
        
        const data = await response.json();
        console.log("\n[EVOLUTION] Resultado de Fable 5:");
        console.log(data.choices[0].message.content);
        
    } catch (e) {
        console.error("[!] Error crítico:", e.message);
    }
}

evolveEcosystem();
