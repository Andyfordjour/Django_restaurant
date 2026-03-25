import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

export interface Employee {
  id?: number;
  name: string;
  email: string;
}


@Injectable({
  providedIn: 'root',
})
export class EmployeeService {

  private api = 'http://localhost:8080/api/employees';

  constructor(private http: HttpClient) {}

  getAll(): Observable<Employee[]> {
    return this.http.get<Employee[]>(this.api);
  }

  create(emp: Employee) {
    return this.http.post(this.api, emp);
  }

  update(id: number, emp: Employee) {
    return this.http.put(`${this.api}/${id}`, emp);
  }

  delete(id: number) {
    return this.http.delete(`${this.api}/${id}`);
  }
}
