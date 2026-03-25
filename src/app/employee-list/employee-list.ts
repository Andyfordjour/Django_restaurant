import { Component, OnInit } from '@angular/core';
import { EmployeeService, Employee } from '../employee';


@Component({
  selector: 'app-employee-list',
  imports: [],
  templateUrl: './employee-list.html',
  styleUrl: './employee-list.css',
})
export class EmployeeList implements OnInit {

  employees: Employee[] = [];

  constructor(private service: EmployeeService) {}

  ngOnInit() {
    this.load();
  }

  load() {
    this.service.getAll().subscribe(data => this.employees = data);
  }

  delete(id: number) {
    this.service.delete(id).subscribe(() => this.load());
  }
}
