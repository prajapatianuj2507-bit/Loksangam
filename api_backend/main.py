from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import List, Optional
from dotenv import load_dotenv
from passlib.context import CryptContext
from motor.motor_asyncio import AsyncIOMotorClient
from pymongo import ReturnDocument
import os
import uuid
import ssl
import certifi
from datetime import datetime
from bson import ObjectId

# Load environment variables
load_dotenv()

# MongoDB Configuration
MONGODB_URL = os.getenv("MONGODB_URL", "mongodb://localhost:27017")
DB_NAME = os.getenv("DB_NAME", "loksangam_db")

# Global MongoDB client
mongodb_client: AsyncIOMotorClient = None
database = None

# --- FastAPI App Initialization ---
app = FastAPI(title="LokSangam Event API", version="1.0.0")

# --- CORS Middleware ---
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # For development - restrict for production!
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Password Context ---
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# --- MongoDB Connection Management ---
@app.on_event("startup")
async def startup_db_client():
    global mongodb_client, database
    try:
        # Create MongoDB client with proper SSL configuration
        mongodb_client = AsyncIOMotorClient(
            MONGODB_URL,
            tls=True,
            tlsCAFile=certifi.where(),
            serverSelectionTimeoutMS=5000,
            connectTimeoutMS=10000,
            socketTimeoutMS=10000,
        )
        database = mongodb_client[DB_NAME]
        
        # Test connection
        await mongodb_client.admin.command('ping')
        print("✅ MongoDB connection successful!")
        
        # Create indexes for better performance (with error handling)
        try:
            # Drop existing problematic indexes if they exist
            existing_indexes = await database.events.index_information()
            if 'id_1' in existing_indexes:
                await database.events.drop_index('id_1')
                print("🔧 Dropped existing id index")
            
            existing_user_indexes = await database.users.index_information()
            if 'email_1' in existing_user_indexes:
                await database.users.drop_index('email_1')
                print("🔧 Dropped existing email index")
            
            existing_reg_indexes = await database.registrations.index_information()
            if 'registration_id_1' in existing_reg_indexes:
                await database.registrations.drop_index('registration_id_1')
                print("🔧 Dropped existing registration_id index")
            
            # Remove documents with null id fields before creating unique index
            delete_result = await database.events.delete_many({"id": None})
            if delete_result.deleted_count > 0:
                print(f"🧹 Cleaned up {delete_result.deleted_count} documents with null id")
            
            delete_result = await database.users.delete_many({"email": None})
            if delete_result.deleted_count > 0:
                print(f"🧹 Cleaned up {delete_result.deleted_count} users with null email")
            
            delete_result = await database.registrations.delete_many({"registration_id": None})
            if delete_result.deleted_count > 0:
                print(f"🧹 Cleaned up {delete_result.deleted_count} registrations with null id")
            
            # Create indexes
            await database.events.create_index("status")
            await database.events.create_index("id", unique=True, sparse=True)
            await database.users.create_index("email", unique=True, sparse=True)
            await database.registrations.create_index("registration_id", unique=True, sparse=True)
            print("✅ Indexes created successfully!")
            
        except Exception as idx_error:
            print(f"⚠  Index creation warning: {idx_error}")
            print("Application will continue without unique indexes")
        
    except Exception as e:
        print(f"❌ MongoDB connection failed: {e}")
        print("\n💡 Troubleshooting tips:")
        print("1. Verify your MONGODB_URL in .env file")
        print("2. Check if your IP is whitelisted in MongoDB Atlas")
        print("3. Ensure your username and password are correct")
        print("4. Try installing/updating certifi: pip install --upgrade certifi")
        raise

@app.on_event("shutdown")
async def shutdown_db_client():
    global mongodb_client
    if mongodb_client:
        mongodb_client.close()
        print("🔌 MongoDB connection closed")

# --- DB Dependency ---
async def get_database():
    return database

# --- Mock Auth/User Context ---
def get_current_user_id():
    return 2

def get_current_user_role():
    return 'admin'

# --- Pydantic Schemas ---
class EventBase(BaseModel):
    name: str = Field(min_length=3, max_length=255)
    event_date: str
    location: str = Field(max_length=255)
    total_seats: int = Field(gt=0)

class EventCreate(EventBase):
    pass

class EventPublic(EventBase):
    id: int
    remaining_seats: int
    status: str
    class Config:
        from_attributes = True

class UserLogin(BaseModel):
    email: str
    password: str

class RegistrationRequest(BaseModel):
    event_id: int
    full_name: str
    email: str
    seats_booked: int = Field(gt=0, le=5)

class RegistrationTicket(BaseModel):
    registration_id: int
    event_name: str
    registered_name: str
    seats: int
    qr_data: str

# --- Utility Functions ---
def verify_password(plain_password: str, hashed_password: str) -> bool:
    try:
        return pwd_context.verify(plain_password, hashed_password)
    except Exception:
        return False

async def get_next_sequence(db, sequence_name: str) -> int:
    """Generate auto-incrementing IDs like MySQL"""
    result = await db.counters.find_one_and_update(
        {"_id": sequence_name},
        {"$inc": {"sequence_value": 1}},
        upsert=True,
        return_document=ReturnDocument.AFTER
    )
    return result["sequence_value"]

# --- Endpoints ---
@app.get("/", summary="Check API Status")
async def root():
    return {"message": "LokSangam Event API is running! 🚀"}

@app.post("/login", tags=["Auth"], summary="Authenticate User")
async def login_user(user: UserLogin, db = Depends(get_database)):
    db_user = await db.users.find_one({"email": user.email})
    
    if not db_user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, 
            detail="Invalid credentials"
        )
    
    if not verify_password(user.password, db_user.get('password_hash', '')):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, 
            detail="Invalid credentials"
        )
    
    return {
        "message": "Login successful",
        "user_id": db_user.get('id', db_user.get('user_id')),
        "role": db_user.get('role', 'user'),
        "access_token": f"mock_{db_user.get('role', 'user')}token{db_user.get('id', '')}",
    }

@app.get("/events", response_model=List[EventPublic], tags=["Events"], summary="List all verified events")
async def list_verified_events(db = Depends(get_database)):
    cursor = db.events.find({"status": "verified"})
    events_data = await cursor.to_list(length=None)
    
    result = []
    for event in events_data:
        result.append(EventPublic(
            id=event.get('id', 0),
            name=event.get('name', ''),
            event_date=event.get('event_date', ''),
            location=event.get('location', ''),
            total_seats=event.get('total_seats', 0),
            remaining_seats=event.get('remaining_seats', 0),
            status=event.get('status', '')
        ))
    
    return result

@app.post("/event/request", status_code=status.HTTP_201_CREATED, tags=["Events"], summary="Submit a new event request")
async def submit_event_request(event: EventCreate, db = Depends(get_database)):
    user_id = 2
    
    # Get next event ID
    event_id = await get_next_sequence(db, "event_id")
    
    event_doc = {
        "id": event_id,
        "name": event.name,
        "event_date": event.event_date,
        "location": event.location,
        "total_seats": event.total_seats,
        "remaining_seats": event.total_seats,
        "status": "pending",
        "requested_by_user_id": user_id,
        "created_at": datetime.utcnow()
    }
    
    try:
        await db.events.insert_one(event_doc)
        return {"message": "Event request submitted successfully. Waiting for admin verification."}
    except Exception as err:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, 
            detail=f"Database error during insert: {err}"
        )

@app.post("/event/register", response_model=RegistrationTicket, tags=["Events"], summary="Book seats for an event (Atomic Transaction)")
async def register_event(
    reg_request: RegistrationRequest, 
    db = Depends(get_database)
):
    seats_to_book = reg_request.seats_booked
    event_id = reg_request.event_id
    current_user_id = get_current_user_id()
    
    # Start a session for transaction
    async with await mongodb_client.start_session() as session:
        async with session.start_transaction():
            try:
                # Find and lock the event
                event_info = await db.events.find_one(
                    {"id": event_id, "status": "verified"},
                    session=session
                )
                
                if not event_info:
                    raise HTTPException(
                        status_code=status.HTTP_404_NOT_FOUND, 
                        detail="Event not found or not verified"
                    )
                
                event_name = event_info['name']
                remaining_seats = event_info['remaining_seats']
                
                if remaining_seats < seats_to_book:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST, 
                        detail=f"Only {remaining_seats} seats remaining."
                    )
                
                new_remaining_seats = remaining_seats - seats_to_book
                
                # Update event seats
                await db.events.update_one(
                    {"id": event_id},
                    {"$set": {"remaining_seats": new_remaining_seats}},
                    session=session
                )
                
                # Generate QR data
                qr_data = f"{reg_request.full_name}|{reg_request.email}|{event_id}|{seats_to_book}|{uuid.uuid4()}"
                
                # Get next registration ID
                registration_id = await get_next_sequence(db, "registration_id")
                
                # Create registration document
                registration_doc = {
                    "registration_id": registration_id,
                    "user_id": current_user_id,
                    "event_id": event_id,
                    "registered_name": reg_request.full_name,
                    "registered_email": reg_request.email,
                    "seats_booked": seats_to_book,
                    "qr_data": qr_data,
                    "created_at": datetime.utcnow()
                }
                
                await db.registrations.insert_one(registration_doc, session=session)
                
                # Commit transaction
                await session.commit_transaction()
                
                return RegistrationTicket(
                    registration_id=registration_id,
                    event_name=event_name,
                    registered_name=reg_request.full_name,
                    seats=seats_to_book,
                    qr_data=qr_data,
                )
                
            except HTTPException as e:
                await session.abort_transaction()
                raise e
            except Exception as e:
                print(f"Transaction failed: {e}")
                await session.abort_transaction()
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, 
                    detail="Registration failed due to a server error."
                )

@app.get("/admin/pending_events", response_model=List[EventPublic], tags=["Admin"], summary="List all pending event requests (Admin Only)")
async def list_pending_events(db = Depends(get_database)):
    if get_current_user_role() != 'admin':
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, 
            detail="Admin privileges required"
        )
    
    cursor = db.events.find({"status": "pending"})
    events_data = await cursor.to_list(length=None)
    
    result = []
    for event in events_data:
        result.append(EventPublic(
            id=event.get('id', 0),
            name=event.get('name', ''),
            event_date=event.get('event_date', ''),
            location=event.get('location', ''),
            total_seats=event.get('total_seats', 0),
            remaining_seats=event.get('remaining_seats', 0),
            status=event.get('status', '')
        ))
    
    return result

@app.post("/admin/verify/{event_id}", tags=["Admin"], summary="Verify a pending event (Admin Only)")
async def verify_event(event_id: int, db = Depends(get_database)):
    if get_current_user_role() != 'admin':
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, 
            detail="Admin privileges required"
        )
    
    result = await db.events.update_one(
        {"id": event_id, "status": "pending"},
        {"$set": {"status": "verified", "verified_at": datetime.utcnow()}}
    )
    
    if result.matched_count == 0:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, 
            detail="Event not found or already verified."
        )
    
    return {"message": f"Event ID {event_id} verified successfully."}