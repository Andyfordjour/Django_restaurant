import { Routes } from '@angular/router';
import { EmployeeList } from './employee-list/employee-list';
import { EmployeeForm } from './employee-form/employee-form';

export const routes: Routes = [
    { path: '', component: EmployeeList },
    { path: 'add', component: EmployeeForm }
];