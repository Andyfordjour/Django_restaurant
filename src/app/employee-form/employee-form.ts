import { Component } from '@angular/core';
import { EmployeeService } from '../employee';
import { Router } from '@angular/router';


@Component({
  selector: 'app-employee-form',
  imports: [],
  templateUrl: './employee-form.html',
  styleUrl: './employee-form.css',
})
export class EmployeeForm {
employee = { name: '', email: '' };

  constructor(private service: EmployeeService, private router: Router) {}

  save() {
    this.service.create(this.employee).subscribe(() => {
      this.router.navigate(['/']);
    });
  }
}

