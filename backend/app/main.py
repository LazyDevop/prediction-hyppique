"""Point d'entrée FastAPI (cahier des charges section 5) — cible uvicorn de
`Dockerfile` (`app.main:app`). Ne fait que rassembler les trois routeurs
existants (courses, chevaux, analyse) sans préfixe de chemin : le
`postman_collection.json` et le mode de repli vision pointent vers des
chemins nus (`/courses`, `/analyse`, `/extraction/*`)."""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes_analyse import router as routes_analyse_router
from app.api.routes_chevaux import router as routes_chevaux_router
from app.api.routes_courses import router as routes_courses_router

app = FastAPI(title="Prediction Hippique")

# Le client mobile est aussi buildable en web (flutter run -d chrome), où le
# navigateur applique CORS entre l'origine localhost du dev server et cette
# API -- sans middleware, toute requête cross-origin échoue silencieusement
# côté navigateur (le client natif Android/iOS n'est lui pas concerné).
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(routes_courses_router)
app.include_router(routes_chevaux_router)
app.include_router(routes_analyse_router)
