#!/usr/bin/env python3
"""
Task Extractor for GitLab Migration

Extracts tasks from documentation and code for GitLab issues migration.
Supports markdown checklists, TODO comments, and structured task documents.
"""

import re
import json
import yaml
from pathlib import Path
from typing import List, Dict, Any, Optional
from dataclasses import dataclass
import argparse

@dataclass
class Task:
    """Represents a task extracted from documentation or code"""
    title: str
    description: str
    source_file: str
    source_line: int
    task_type: str  # 'markdown', 'todo', 'roadmap'
    status: str     # 'not_started', 'in_progress', 'completed', 'cancelled'
    priority: str   # 'Critical', 'High', 'Medium', 'Low'
    epic: Optional[str] = None
    component: Optional[str] = None
    context: Optional[str] = None
    original_content: Optional[str] = None

class TaskExtractor:
    """Extract tasks from various sources in the repository"""
    
    def __init__(self, repo_root: str):
        self.repo_root = Path(repo_root)
        self.tasks = []
        
        # Patterns for different task types
        self.markdown_patterns = {
            'not_started': r'- \[ \]',
            'in_progress': r'- \[/\]',
            'completed': r'- \[x\]',
            'cancelled': r'- \[-\]'
        }
        
        self.todo_patterns = [
            'TODO:', 'FIXME:', 'HACK:', 'XXX:', 'NOTE:'
        ]
        
        # Priority keywords for automatic classification
        self.priority_keywords = {
            'Critical': ['critical', 'blocking', 'urgent', 'immediate'],
            'High': ['important', 'high', 'priority', 'must'],
            'Medium': ['should', 'medium', 'normal'],
            'Low': ['nice', 'low', 'future', 'optional']
        }
        
        # Epic classification keywords
        self.epic_keywords = {
            'epic::mathematical-core': ['precision', 'algorithm', 'mathematical', 'core'],
            'epic::test-framework': ['test', 'testing', 'validation', 'coverage'],
            'epic::performance': ['performance', 'optimization', 'memory', 'speed'],
            'epic::documentation': ['documentation', 'docs', 'guide', 'tutorial'],
            'epic::hpc-deployment': ['hpc', 'cluster', 'deployment', 'slurm'],
            'epic::visualization': ['plot', 'visualization', 'dashboard', 'graph'],
            'epic::advanced-features': ['advanced', 'feature', 'enhancement']
        }
        
        # Component classification keywords
        self.component_keywords = {
            'component::core': ['core', 'algorithm', 'mathematical'],
            'component::precision': ['precision', 'adaptive', 'bigfloat'],
            'component::grids': ['grid', 'anisotropic', 'tensor'],
            'component::solvers': ['solver', 'polynomial', 'homotopy'],
            'component::hpc': ['hpc', 'cluster', 'slurm', 'deployment'],
            'component::testing': ['test', 'testing', 'validation'],
            'component::plotting': ['plot', 'visualization', 'makie']
        }

    def extract_markdown_tasks(self, file_path: Path) -> List[Task]:
        """Extract markdown checklist tasks from a file"""
        tasks = []
        
        try:
            content = file_path.read_text(encoding='utf-8')
            lines = content.split('\n')
            
            for line_num, line in enumerate(lines, 1):
                for status, pattern in self.markdown_patterns.items():
                    if re.search(pattern, line):
                        # Extract task text
                        task_text = re.sub(r'- \[.\]', '', line).strip()
                        if not task_text:
                            continue
                            
                        # Create task
                        task = Task(
                            title=self._extract_title(task_text),
                            description=task_text,
                            source_file=str(file_path.relative_to(self.repo_root)),
                            source_line=line_num,
                            task_type='markdown',
                            status=status,
                            priority=self._classify_priority(task_text),
                            epic=self._classify_epic(task_text),
                            component=self._classify_component(task_text),
                            context=self._extract_context(lines, line_num),
                            original_content=line.strip()
                        )
                        tasks.append(task)
                        break
                        
        except Exception as e:
            print(f"Error processing {file_path}: {e}")
            
        return tasks

    def extract_todo_comments(self, file_path: Path) -> List[Task]:
        """Extract TODO/FIXME comments from code files"""
        tasks = []
        
        try:
            content = file_path.read_text(encoding='utf-8')
            lines = content.split('\n')
            
            for line_num, line in enumerate(lines, 1):
                for pattern in self.todo_patterns:
                    if pattern.upper() in line.upper():
                        # Extract TODO text
                        todo_start = line.upper().find(pattern.upper())
                        if todo_start != -1:
                            todo_text = line[todo_start + len(pattern):].strip()
                            if not todo_text:
                                continue
                                
                            # Determine priority based on pattern
                            priority = 'High' if pattern in ['FIXME:', 'HACK:'] else 'Medium'
                            
                            task = Task(
                                title=self._extract_title(todo_text),
                                description=todo_text,
                                source_file=str(file_path.relative_to(self.repo_root)),
                                source_line=line_num,
                                task_type='todo',
                                status='not_started',
                                priority=priority,
                                epic=self._classify_epic(todo_text),
                                component=self._classify_component(todo_text),
                                context=self._extract_context(lines, line_num),
                                original_content=line.strip()
                            )
                            tasks.append(task)
                            break
                            
        except Exception as e:
            print(f"Error processing {file_path}: {e}")
            
        return tasks

    def extract_roadmap_items(self, file_path: Path) -> List[Task]:
        """Extract structured items from roadmap and planning documents"""
        tasks = []
        
        # Special handling for roadmap documents
        if 'roadmap' in file_path.name.lower() or 'plan' in file_path.name.lower():
            try:
                content = file_path.read_text(encoding='utf-8')
                
                # Look for structured sections
                sections = re.split(r'^##\s+', content, flags=re.MULTILINE)
                
                for section in sections:
                    if not section.strip():
                        continue
                        
                    lines = section.split('\n')
                    section_title = lines[0].strip()
                    
                    # Extract tasks from this section
                    for line_num, line in enumerate(lines[1:], 2):
                        # Look for various task indicators
                        if any(indicator in line for indicator in ['- [ ]', '- [x]', '- [/]', '- [-]']):
                            task_text = re.sub(r'- \[.\]', '', line).strip()
                            if task_text:
                                status = self._determine_status_from_line(line)
                                
                                task = Task(
                                    title=self._extract_title(task_text),
                                    description=task_text,
                                    source_file=str(file_path.relative_to(self.repo_root)),
                                    source_line=line_num,
                                    task_type='roadmap',
                                    status=status,
                                    priority=self._classify_priority(task_text + ' ' + section_title),
                                    epic=self._classify_epic(task_text + ' ' + section_title),
                                    component=self._classify_component(task_text + ' ' + section_title),
                                    context=f"Section: {section_title}",
                                    original_content=line.strip()
                                )
                                tasks.append(task)
                                
            except Exception as e:
                print(f"Error processing roadmap {file_path}: {e}")
                
        return tasks

    def _extract_title(self, text: str) -> str:
        """Extract a concise title from task text"""
        # Remove common prefixes and clean up
        text = re.sub(r'^(TODO:|FIXME:|HACK:|XXX:|NOTE:)', '', text).strip()
        
        # Take first sentence or first 60 characters
        sentences = re.split(r'[.!?]', text)
        title = sentences[0].strip()
        
        if len(title) > 60:
            title = title[:57] + '...'
            
        return title

    def _classify_priority(self, text: str) -> str:
        """Classify priority based on text content"""
        text_lower = text.lower()
        
        for priority, keywords in self.priority_keywords.items():
            if any(keyword in text_lower for keyword in keywords):
                return priority
                
        return 'Medium'  # Default priority

    def _classify_epic(self, text: str) -> Optional[str]:
        """Classify epic based on text content"""
        text_lower = text.lower()
        
        for epic, keywords in self.epic_keywords.items():
            if any(keyword in text_lower for keyword in keywords):
                return epic
                
        return None

    def _classify_component(self, text: str) -> Optional[str]:
        """Classify component based on text content"""
        text_lower = text.lower()
        
        for component, keywords in self.component_keywords.items():
            if any(keyword in text_lower for keyword in keywords):
                return component
                
        return None

    def _extract_context(self, lines: List[str], line_num: int) -> str:
        """Extract surrounding context for better understanding"""
        start = max(0, line_num - 3)
        end = min(len(lines), line_num + 2)
        
        context_lines = []
        for i in range(start, end):
            if i != line_num - 1:  # Skip the actual task line
                line = lines[i].strip()
                if line and not line.startswith('#'):
                    context_lines.append(line)
                    
        return ' '.join(context_lines[:2])  # Limit context

    def _determine_status_from_line(self, line: str) -> str:
        """Determine task status from markdown checkbox"""
        if '- [x]' in line:
            return 'completed'
        elif '- [/]' in line:
            return 'in_progress'
        elif '- [-]' in line:
            return 'cancelled'
        else:
            return 'not_started'

    def scan_repository(self, include_patterns: List[str] = None, 
                       exclude_patterns: List[str] = None) -> List[Task]:
        """Scan the entire repository for tasks"""
        if include_patterns is None:
            include_patterns = ['**/*.md', '**/*.jl', '**/*.py']
            
        if exclude_patterns is None:
            exclude_patterns = ['.git/**', 'node_modules/**', 'build/**']
            
        all_tasks = []
        
        for pattern in include_patterns:
            for file_path in self.repo_root.glob(pattern):
                if file_path.is_file():
                    # Check if file should be excluded
                    relative_path = file_path.relative_to(self.repo_root)
                    if any(relative_path.match(exclude) for exclude in exclude_patterns):
                        continue
                        
                    # Extract tasks based on file type
                    if file_path.suffix == '.md':
                        all_tasks.extend(self.extract_markdown_tasks(file_path))
                        all_tasks.extend(self.extract_roadmap_items(file_path))
                    elif file_path.suffix in ['.jl', '.py']:
                        all_tasks.extend(self.extract_todo_comments(file_path))
                        
        self.tasks = all_tasks
        return all_tasks

    def export_to_json(self, output_path: str) -> None:
        """Export extracted tasks to JSON format"""
        task_data = []
        
        for task in self.tasks:
            task_dict = {
                'title': task.title,
                'description': task.description,
                'source_file': task.source_file,
                'source_line': task.source_line,
                'task_type': task.task_type,
                'status': task.status,
                'priority': task.priority,
                'epic': task.epic,
                'component': task.component,
                'context': task.context,
                'original_content': task.original_content
            }
            task_data.append(task_dict)
            
        with open(output_path, 'w') as f:
            json.dump(task_data, f, indent=2)
            
        print(f"Exported {len(task_data)} tasks to {output_path}")

    def generate_summary_report(self) -> str:
        """Generate a summary report of extracted tasks"""
        if not self.tasks:
            return "No tasks found."
            
        # Count by various categories
        by_type = {}
        by_status = {}
        by_priority = {}
        by_epic = {}
        
        for task in self.tasks:
            by_type[task.task_type] = by_type.get(task.task_type, 0) + 1
            by_status[task.status] = by_status.get(task.status, 0) + 1
            by_priority[task.priority] = by_priority.get(task.priority, 0) + 1
            if task.epic:
                by_epic[task.epic] = by_epic.get(task.epic, 0) + 1
                
        report = f"""
Task Extraction Summary
======================

Total Tasks: {len(self.tasks)}

By Type:
{self._format_counts(by_type)}

By Status:
{self._format_counts(by_status)}

By Priority:
{self._format_counts(by_priority)}

By Epic:
{self._format_counts(by_epic)}
"""
        return report

    def _format_counts(self, counts: Dict[str, int]) -> str:
        """Format count dictionary for display"""
        if not counts:
            return "  None"
            
        lines = []
        for key, count in sorted(counts.items()):
            lines.append(f"  {key}: {count}")
        return '\n'.join(lines)


def main():
    parser = argparse.ArgumentParser(description='Extract tasks for GitLab migration')
    parser.add_argument('--repo-root', default='.', help='Repository root directory')
    parser.add_argument('--output', default='extracted_tasks.json', help='Output JSON file')
    parser.add_argument('--summary', action='store_true', help='Print summary report')
    
    args = parser.parse_args()
    
    extractor = TaskExtractor(args.repo_root)
    tasks = extractor.scan_repository()
    
    if args.summary:
        print(extractor.generate_summary_report())
        
    extractor.export_to_json(args.output)


if __name__ == '__main__':
    main()
