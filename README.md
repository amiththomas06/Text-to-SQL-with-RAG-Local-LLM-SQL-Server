# Text-to-SQL Agent with RAG

Ask questions about a SQL Server database in plain English and get a written analysis back. The agent is powered by an open-source LLM running **locally** through [Ollama](https://ollama.com), so no data leaves your machine.

```
"What is the total revenue for premium customers last quarter,
 and how does it compare with the previous quarter?"
```

A fixed pipeline retrieves the relevant business rules from a data dictionary (RAG), has the LLM write T-SQL using those rules and the schema, runs it (feeding any error back so the model can fix it), and then has the LLM explain the results. It shows the SQL and raw data alongside the answer so you can check it.

A fixed pipeline is used instead of an autonomous agent because 7B local models are unreliable at multi-step tool calling. They tend to repeat steps or stop early.

## Tech stack

- **LLM:** `qwen2.5-coder:7b` via Ollama
- **Orchestration:** LangChain 0.3 (fixed retrieve → generate SQL → run → explain pipeline)
- **RAG:** `all-MiniLM-L6-v2` embeddings + Chroma
- **Database:** SQL Server Express (`pyodbc` + SQLAlchemy)

## Project files

| File | Purpose |
|---|---|
| `text_to_sql_agent.ipynb` | The agent, explained step by step |
| `data_dictionary.txt` | Business rules and metric definitions the agent retrieves |
| `create_TextToSQLDemo.sql` | Creates and populates the demo database |
| `requirements.txt` | Python dependencies |

## Setup

1. **Install Ollama** from [ollama.com/download](https://ollama.com/download), then pull the model:
   ```bash
   ollama pull qwen2.5-coder:7b
   ```
2. **Install SQL Server Express**, SSMS, and ODBC Driver 17 or 18 for SQL Server.
3. **Create the demo database:** open `create_TextToSQLDemo.sql` in SSMS (connected to `localhost\SQLEXPRESS`) and press F5.
4. **Create a Python 3.12 environment** and install dependencies:
   ```bash
   py -V:3.12 -m venv venv312
   venv312\Scripts\activate
   pip install -r requirements.txt
   ```
5. **Open the notebook** in VS Code or Jupyter, select the `venv312` kernel, and run the cells in order.

If your SQL Server instance has a different name, change `SERVER` in the configuration cell.

## Example

```python
ask("Which year had the highest revenue?")
```

Output includes the SQL executed, the raw result, and a written answer.

## Limitations

- 7B models can write SQL that runs but misses part of a business rule. Always check the printed SQL, and use the validation cell in the notebook to compare.
- The agent executes the SQL it writes. Use a **read-only** login and never connect it to a production database.
- The demo data is randomly generated.
