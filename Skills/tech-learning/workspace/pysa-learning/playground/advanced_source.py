import os
import subprocess
import sqlite3
import pickle
import yaml

# RCE via os.system
def rce_os_system():
    user_input = input("Enter command: ")
    os.system(user_input)

# RCE via subprocess
def rce_subprocess():
    user_input = input("Enter process: ")
    subprocess.run(user_input, shell=True)

# SQL injection
def sql_injection():
    user_input = input("Enter name: ")
    conn = sqlite3.connect("test.db")
    cursor = conn.cursor()
    query = "SELECT * FROM users WHERE name = '{}'".format(user_input)
    cursor.execute(query)
    return cursor.fetchall()

# Deserialization vulnerability
def unsafe_deserialization():
    user_data = input("Enter data: ")
    obj = pickle.loads(user_data.encode())
    return obj

# YAML deserialization vulnerability
def unsafe_yaml_load():
    config_str = input("Enter YAML config: ")
    return yaml.load(config_str)

# Safe function (sanitized)
def safe_function():
    user_input = input("Enter number: ")
    safe_value = int(user_input)  # This acts as a sanitizer in some sense
    return safe_value

# Indirect flow through multiple functions
def step1():
    return input("data: ")

def step2(data):
    return "prefix_" + data

def step3(data):
    os.system(data)

def indirect_rce():
    d = step1()
    d2 = step2(d)
    step3(d2)
